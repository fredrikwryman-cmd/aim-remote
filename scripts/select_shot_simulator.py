#!/usr/bin/env python3
"""Valjer en simulator med en viss punktstorlek for designbilderna.

Punktstorleken finns inte i simctl, sa modellnamnen listas i prioritetsordning
per storlek. Skriver simulatorns UDID pa stdout och vad som hittades pa stderr.

Anvandning: select_shot_simulator.py 390x844 | 375x667
"""
import json
import subprocess
import sys

MODELS = {
    "390x844": ["iPhone 16e", "iPhone 14", "iPhone 13", "iPhone 12", "iPhone 13 Pro", "iPhone 14 Pro"],
    "375x667": ["iPhone SE (3rd generation)", "iPhone SE (2nd generation)", "iPhone 8", "iPhone SE"],
}


def available() -> dict:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "--json"], text=True
    )
    found = {}
    for _, group in json.loads(raw).get("devices", {}).items():
        for device in group:
            if device.get("isAvailable") is False:
                continue
            found.setdefault(device.get("name", ""), device.get("udid"))
    return found


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in MODELS:
        print("Anvandning: select_shot_simulator.py 390x844 | 375x667", file=sys.stderr)
        return 2
    size = sys.argv[1]
    devices = available()
    print("# tillgangliga: %s" % ", ".join(sorted(devices)), file=sys.stderr)
    for name in MODELS[size]:
        if name in devices:
            print("# %s -> %s (%s)" % (size, name, devices[name]), file=sys.stderr)
            print(devices[name])
            return 0
    print(
        "Ingen simulator med %s hittades. Provade: %s" % (size, ", ".join(MODELS[size])),
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
