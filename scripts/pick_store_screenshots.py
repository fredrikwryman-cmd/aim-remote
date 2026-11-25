#!/usr/bin/env python3
"""Plockar ut butiksbilderna ur designbilderna och namnger dem i den ordning
App Store ska visa dem.

Designtesterna (UITests/DesignShotTests.swift) tar fler bilder an butiken
behover. Harifran tas fem skarmar i tva lagen, morkt forst eftersom det ar
appens standardlage:

    01 Fjarr            06 Fjarr (ljust)
    02 Valj TV          07 Valj TV (ljust)
    03 Sifferknappar    08 Sifferknappar (ljust)
    04 Tangentbord      09 Tangentbord (ljust)
    05 Installningar    10 Installningar (ljust)

Tio bilder ar ocksa precis sa manga App Store tar emot per storlek.

Varje bild kontrolleras mot den pixelstorlek som begardes. Har bilden en
alfakanal plattas den till RGB, for App Store avvisar skarmbilder med
alfakanal. Inga ramar och ingen text laggs pa: bilderna ar raka
skarmbilder.

Anvandning: pick_store_screenshots.py <inmapp> <utmapp> <bredd>x<hojd>
"""
import pathlib
import re
import struct
import sys
import zlib

# Skarm -> (ordning morkt, ordning ljust, filnamnsdel)
SCREENS = [
    ("R02_fjarr", 1, 6, "fjarr"),
    ("R04_valj-tv", 2, 7, "valj-tv"),
    ("P05_123", 3, 8, "123"),
    ("P06_tangentbord", 4, 9, "tangentbord"),
    ("R03_installningar", 5, 10, "installningar"),
]

MODES = {"dark": ("mork", 0), "light": ("ljus", 1)}


def png_header(data: bytes):
    """(bredd, hojd, bitdjup, fargtyp) ur IHDR."""
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return None
    width, height = struct.unpack(">II", data[16:24])
    return width, height, data[24], data[25]


def chunks(data: bytes):
    offset = 8
    while offset < len(data):
        (length,) = struct.unpack(">I", data[offset:offset + 4])
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        yield kind, payload
        offset += 12 + length


def build(width: int, height: int, raw: bytes) -> bytes:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        body = kind + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(raw, 6))
            + chunk(b"IEND", b""))


def drop_alpha(data: bytes) -> bytes:
    """Plattar en RGBA-PNG till RGB mot vitt. Bara stdlib, ingen Pillow."""
    width, height, depth, kind = png_header(data)
    if kind != 6 or depth != 8:
        raise ValueError("kan bara platta 8-bitars RGBA, fick fargtyp %d djup %d" % (kind, depth))
    stream = b"".join(payload for name, payload in chunks(data) if name == b"IDAT")
    flat = zlib.decompress(stream)

    source_stride = width * 4
    target_stride = width * 3
    previous = bytearray(source_stride)
    out = bytearray()
    position = 0
    for _ in range(height):
        filter_type = flat[position]
        position += 1
        line = bytearray(flat[position:position + source_stride])
        position += source_stride
        # PNG-filtren, enligt specen. bpp ar 4 for RGBA.
        if filter_type == 1:
            for index in range(4, source_stride):
                line[index] = (line[index] + line[index - 4]) & 0xFF
        elif filter_type == 2:
            for index in range(source_stride):
                line[index] = (line[index] + previous[index]) & 0xFF
        elif filter_type == 3:
            for index in range(source_stride):
                left = line[index - 4] if index >= 4 else 0
                line[index] = (line[index] + ((left + previous[index]) >> 1)) & 0xFF
        elif filter_type == 4:
            for index in range(source_stride):
                left = line[index - 4] if index >= 4 else 0
                up = previous[index]
                upleft = previous[index - 4] if index >= 4 else 0
                estimate = left + up - upleft
                pa, pb, pc = abs(estimate - left), abs(estimate - up), abs(estimate - upleft)
                nearest = left if (pa <= pb and pa <= pc) else (up if pb <= pc else upleft)
                line[index] = (line[index] + nearest) & 0xFF
        elif filter_type != 0:
            raise ValueError("okant PNG-filter %d" % filter_type)
        previous = line

        row = bytearray(target_stride + 1)
        for pixel in range(width):
            red, green, blue, alpha = line[pixel * 4:pixel * 4 + 4]
            if alpha != 255:
                inverse = 255 - alpha
                red = (red * alpha + 255 * inverse) // 255
                green = (green * alpha + 255 * inverse) // 255
                blue = (blue * alpha + 255 * inverse) // 255
            row[1 + pixel * 3:4 + pixel * 3] = bytes((red, green, blue))
        out += row
    return build(width, height, bytes(out))


def find(folder: pathlib.Path, stem: str, mode: str):
    """Bilden heter <stem>_<mode>[_<storlek>].png, med eller utan loparnummer."""
    pattern = re.compile(r"^%s_%s(_|$|\.)" % (re.escape(stem), mode))
    hits = sorted(path for path in folder.rglob("*.png") if pattern.match(path.name))
    return hits[0] if hits else None


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    source = pathlib.Path(sys.argv[1])
    target = pathlib.Path(sys.argv[2])
    size = sys.argv[3]
    try:
        want_width, want_height = (int(part) for part in size.split("x"))
    except ValueError:
        print("Storleken ska skrivas <bredd>x<hojd>, t.ex. 1206x2622", file=sys.stderr)
        return 2

    target.mkdir(parents=True, exist_ok=True)
    written, missing, wrong = 0, [], []

    for stem, dark_order, light_order, label in SCREENS:
        for mode, (swedish, _) in MODES.items():
            order = dark_order if mode == "dark" else light_order
            found = find(source, stem, mode)
            name = "%02d-%s-%s.png" % (order, label, swedish)
            if found is None:
                missing.append(name)
                continue
            data = found.read_bytes()
            header = png_header(data)
            if header is None:
                wrong.append("%s: inte en PNG" % found.name)
                continue
            width, height, _, kind = header
            if (width, height) != (want_width, want_height):
                wrong.append("%s: %dx%d, inte %s" % (found.name, width, height, size))
                continue
            if kind in (4, 6):
                print("# %s har alfakanal, plattas till RGB" % found.name, file=sys.stderr)
                data = drop_alpha(data)
            (target / name).write_bytes(data)
            print(target / name)
            written += 1

    print("Skrev %d av %d bilder till %s" % (written, len(SCREENS) * 2, target))
    for item in missing:
        print("::warning::saknas: %s" % item)
    for item in wrong:
        print("::warning::fel bild: %s" % item)
    # Butiken behover bada lagena av alla fem skarmarna.
    return 0 if written == len(SCREENS) * 2 else 1


if __name__ == "__main__":
    raise SystemExit(main())
