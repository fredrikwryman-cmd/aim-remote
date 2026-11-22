#!/usr/bin/env python3
"""Skriver App Store Connect-nyckeln ur ASC_KEY_P8 till angiven sokvag.

Secreten forvantas vara base64 av .p8-filen. Ar den i stallet inklistrad
som ren PEM-text anvands den som den ar, sa att ett vanligt misstag vid
inlaggningen inte stoppar bygget.
"""
import base64
import os
import pathlib
import sys

MARKER = b"PRIVATE KEY"


def main() -> int:
    if len(sys.argv) != 2:
        print("Anvandning: write_asc_key.py <sokvag>", file=sys.stderr)
        return 2
    raw = os.environ.get("ASC_KEY_P8", "")
    if not raw.strip():
        print("ASC_KEY_P8 ar tom.", file=sys.stderr)
        return 1

    data = b""
    try:
        data = base64.b64decode(raw, validate=False)
    except Exception:
        data = b""
    if MARKER not in data:
        data = raw.encode()
    if MARKER not in data:
        print(
            "ASC_KEY_P8 ar varken base64 av en .p8-fil eller PEM-text. "
            "Lagg in filens innehall base64-kodat.",
            file=sys.stderr,
        )
        return 1

    path = pathlib.Path(sys.argv[1])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    print("Skrev nyckel till %s (%d byte)" % (path, len(data)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
