#!/usr/bin/env python3
"""Kontrollerar en exporterad ad hoc-app fore nedladdning.

Skriver ut bundle-id, version och build ur Info.plist och visar om den
inbaddade provisioneringsprofilen innehaller angivet UDID. Saknas UDID:t
avslutas skriptet med fel, eftersom appen da inte gar att installera pa
telefonen.

Anvandning: check_adhoc_build.py <sokvag till .app> <udid>
"""
import pathlib
import plistlib
import subprocess
import sys


def read_profile(app: pathlib.Path) -> dict:
    profile = app / "embedded.mobileprovision"
    if not profile.is_file():
        print("Ingen embedded.mobileprovision i %s" % app, file=sys.stderr)
        return {}
    # security cms -D packar upp den CMS-signerade profilen till en plist.
    raw = subprocess.check_output(["security", "cms", "-D", "-i", str(profile)])
    return plistlib.loads(raw)


def main() -> int:
    if len(sys.argv) != 3:
        print("Anvandning: check_adhoc_build.py <.app> <udid>", file=sys.stderr)
        return 2
    app = pathlib.Path(sys.argv[1])
    udid = sys.argv[2].strip()
    info_path = app / "Info.plist"
    if not info_path.is_file():
        print("Hittar ingen Info.plist i %s" % app, file=sys.stderr)
        return 1

    with info_path.open("rb") as handle:
        info = plistlib.load(handle)
    print("Bundle-id: %s" % info.get("CFBundleIdentifier"))
    print("Version:   %s" % info.get("CFBundleShortVersionString"))
    print("Build:     %s" % info.get("CFBundleVersion"))

    profile = read_profile(app)
    if not profile:
        return 1
    print("Profil:    %s" % profile.get("Name"))
    print("Team:      %s" % ", ".join(profile.get("TeamIdentifier", [])))
    print("Utgar:     %s" % profile.get("ExpirationDate"))

    devices = profile.get("ProvisionedDevices") or []
    print("Enheter i profilen: %d" % len(devices))
    for device in devices:
        print("  - %s" % device)
    if any(str(device).lower() == udid.lower() for device in devices):
        print("OK: %s finns i den inbaddade profilen." % udid)
        return 0
    print(
        "UDID %s finns INTE i den inbaddade profilen. Appen gar inte att "
        "installera pa telefonen." % udid,
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
