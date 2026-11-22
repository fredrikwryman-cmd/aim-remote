#!/usr/bin/env python3
"""Valjer nyaste stabila Xcode pa runnern.

Skriver sokvagen till Xcode-appen pa stdout och vad som hittades pa stderr.
Betaversioner hoppas over. Versionen lases ur Contents/version.plist nar den
finns, annars ur mappnamnet, sa att inget ar last till en viss version.
"""
import pathlib
import plistlib
import re
import sys

APPLICATIONS = pathlib.Path("/Applications")
VERSION_IN_NAME = re.compile(r"(\d+(?:\.\d+)*)")


def version_of(app: pathlib.Path):
    plist = app / "Contents" / "version.plist"
    if plist.is_file():
        try:
            with plist.open("rb") as handle:
                info = plistlib.load(handle)
            short = str(info.get("CFBundleShortVersionString", "")).strip()
            if short:
                match = VERSION_IN_NAME.match(short)
                if match:
                    return tuple(int(p) for p in match.group(1).split("."))
        except Exception as error:  # noqa: BLE001
            print("# kunde inte lasa %s: %s" % (plist, error), file=sys.stderr)
    match = VERSION_IN_NAME.search(app.name)
    if match:
        return tuple(int(p) for p in match.group(1).split("."))
    return None


def main() -> int:
    candidates = {}
    for app in sorted(APPLICATIONS.glob("Xcode*.app")):
        if "beta" in app.name.lower():
            print("# hoppar over beta: %s" % app.name, file=sys.stderr)
            continue
        if not (app / "Contents" / "Developer").is_dir():
            continue
        resolved = app.resolve()
        version = version_of(app)
        if version is None:
            print("# ingen version for %s" % app.name, file=sys.stderr)
            continue
        # Xcode.app ar ofta en symlink till en versionsnumrerad app. Behall den
        # med tydligast namn for samma faktiska installation.
        previous = candidates.get(resolved)
        if previous is None or len(app.name) > len(previous[1].name):
            candidates[resolved] = (version, app)

    if not candidates:
        print("Hittade ingen stabil Xcode under /Applications.", file=sys.stderr)
        return 1

    found = sorted(candidates.values(), key=lambda item: item[0], reverse=True)
    for version, app in found:
        print(
            "# %-24s %s" % (".".join(str(p) for p in version), app),
            file=sys.stderr,
        )
    version, app = found[0]
    print("# vald: Xcode %s" % ".".join(str(p) for p in version), file=sys.stderr)
    print(app)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
