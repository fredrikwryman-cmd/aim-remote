#!/usr/bin/env python3
"""Skriver ExportOptions.plist for App Store Connect-export.

Nyckeln method ar app-store-connect fran Xcode 15.3 och app-store i aldre
versioner. Ratt varde valjs utifran xcodebuild -version sa att samma
workflow fungerar nar runnerns Xcode byts ut.
"""
import os
import pathlib
import plistlib
import re
import subprocess
import sys


def xcode_version() -> tuple:
    try:
        out = subprocess.check_output(["xcodebuild", "-version"], text=True)
    except Exception:
        return (0, 0)
    match = re.search(r"Xcode\s+(\d+)(?:\.(\d+))?", out)
    if not match:
        return (0, 0)
    return (int(match.group(1)), int(match.group(2) or 0))


def main() -> int:
    if len(sys.argv) != 2:
        print("Anvandning: export_options.py <sokvag>", file=sys.stderr)
        return 2
    team = os.environ.get("DEVELOPMENT_TEAM", "").strip()
    if not team:
        print("DEVELOPMENT_TEAM saknas.", file=sys.stderr)
        return 1

    major, minor = xcode_version()
    modern = (major, minor) >= (15, 3)
    options = {
        "method": "app-store-connect" if modern else "app-store",
        "destination": "export",
        "teamID": team,
        "signingStyle": "automatic",
        "uploadSymbols": True,
        "manageAppVersionAndBuildNumber": False,
    }

    path = pathlib.Path(sys.argv[1])
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        plistlib.dump(options, handle)
    print("Xcode %d.%d, method=%s" % (major, minor, options["method"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
