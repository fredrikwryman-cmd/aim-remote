#!/usr/bin/env python3
"""Plockar ut skarmbilderna ur ett .xcresult och skriver dem som PNG.

Xcode 26 har tagit bort det gamla JSON-formatet ur "xcresulttool get": det
svarar exit 64 och hanvisar till --legacy. Darfor anvands i forsta hand
"xcresulttool export attachments", som skriver alla bilagor plus en
manifest.json. Gar det inte lases resultatet med --legacy som reserv.

Filnamnen blir bilagans namn (R01_start_dark, R02_fjarr_dark,
R02_fjarr_light) plus storleken, t.ex. R02_fjarr_dark_390x844.png.

Anvandning: export_screenshots.py <sokvag.xcresult> <utmapp> [storlek]
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

SAFE = re.compile(r"[^A-Za-z0-9_.-]+")


def run(args: list) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True)


def clean(name: str) -> str:
    name = SAFE.sub("_", name.strip()).strip("_")
    return name or "bild"


def target_name(name: str, suffix: str, taken: set) -> str:
    stem = clean(pathlib.Path(name).stem)
    if suffix and not stem.endswith(suffix):
        stem = "%s_%s" % (stem, suffix)
    candidate = stem + ".png"
    counter = 2
    while candidate in taken:
        candidate = "%s_%d.png" % (stem, counter)
        counter += 1
    taken.add(candidate)
    return candidate


def is_image(path: pathlib.Path) -> bool:
    try:
        head = path.open("rb").read(8)
    except OSError:
        return False
    return head.startswith(b"\x89PNG") or head.startswith(b"\xff\xd8\xff")


def from_manifest(result: pathlib.Path, output: pathlib.Path, suffix: str) -> int:
    """Xcode 16 och senare: export attachments + manifest.json."""
    written = 0
    with tempfile.TemporaryDirectory() as temporary:
        staging = pathlib.Path(temporary)
        done = run([
            "xcrun", "xcresulttool", "export", "attachments",
            "--path", str(result), "--output-path", str(staging),
        ])
        if done.returncode != 0:
            print("# export attachments gav %d: %s" % (done.returncode, done.stderr.strip()[:300]),
                  file=sys.stderr)
            return 0

        manifest = staging / "manifest.json"
        entries = []
        if manifest.is_file():
            try:
                data = json.loads(manifest.read_text(encoding="utf-8"))
            except ValueError as error:
                print("# kunde inte lasa manifest.json: %s" % error, file=sys.stderr)
                data = []
            for test in data if isinstance(data, list) else []:
                for item in test.get("attachments", []) or []:
                    exported = item.get("exportedFileName")
                    if not exported:
                        continue
                    label = (
                        item.get("suggestedHumanReadableName")
                        or item.get("name")
                        or exported
                    )
                    entries.append((staging / exported, label))
        else:
            print("# ingen manifest.json, tar alla exporterade filer", file=sys.stderr)
            for path in sorted(staging.iterdir()):
                if path.is_file():
                    entries.append((path, path.name))

        taken = set()
        for path, label in entries:
            if not path.is_file() or not is_image(path):
                continue
            destination = output / target_name(label, suffix, taken)
            shutil.copyfile(path, destination)
            print(destination)
            written += 1
    return written


def from_legacy(result: pathlib.Path, output: pathlib.Path, suffix: str) -> int:
    """Reserv: gamla JSON-tradet via --legacy."""
    visited = set()
    exported = set()
    taken = set()
    written = 0

    def scalar(value):
        return value.get("_value") if isinstance(value, dict) else value

    def load(identifier=None):
        args = ["xcrun", "xcresulttool", "get", "--legacy",
                "--path", str(result), "--format", "json"]
        if identifier:
            args += ["--id", identifier]
        done = run(args)
        if done.returncode != 0:
            print("# get --legacy gav %d: %s" % (done.returncode, done.stderr.strip()[:300]),
                  file=sys.stderr)
            return {}
        try:
            return json.loads(done.stdout)
        except ValueError:
            return {}

    def walk(node):
        nonlocal written
        if isinstance(node, list):
            for item in node:
                walk(item)
            return
        if not isinstance(node, dict):
            return
        name = scalar(node.get("name")) or ""
        identifier = scalar(node.get("payloadRef", {}).get("id"))
        if identifier and name and identifier not in exported:
            destination = output / target_name(name, suffix, taken)
            done = run(["xcrun", "xcresulttool", "export", "--legacy", "--type", "file",
                        "--path", str(result), "--id", identifier,
                        "--output-path", str(destination)])
            exported.add(identifier)
            if done.returncode == 0 and destination.is_file() and is_image(destination):
                print(destination)
                written += 1
            elif destination.is_file():
                destination.unlink()
        for key, value in node.items():
            if key in ("testsRef", "summaryRef") and isinstance(value, dict):
                ref = scalar(value.get("id"))
                if ref and ref not in visited:
                    visited.add(ref)
                    walk(load(ref))
            else:
                walk(value)

    walk(load())
    return written


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print("Anvandning: export_screenshots.py <sokvag.xcresult> <utmapp> [storlek]",
              file=sys.stderr)
        return 2
    result = pathlib.Path(sys.argv[1])
    output = pathlib.Path(sys.argv[2])
    suffix = clean(sys.argv[3]) if len(sys.argv) == 4 else ""
    if not result.exists():
        print("Hittar inget resultat pa %s" % result, file=sys.stderr)
        return 1
    output.mkdir(parents=True, exist_ok=True)

    written = from_manifest(result, output, suffix)
    if written == 0:
        print("# inga bilagor den nya vagen, provar --legacy", file=sys.stderr)
        written = from_legacy(result, output, suffix)

    print("Skrev %d bild(er) till %s" % (written, output))
    # Inga bilder ar ingen krasch: workflowen avgor vad som ska laddas upp.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
