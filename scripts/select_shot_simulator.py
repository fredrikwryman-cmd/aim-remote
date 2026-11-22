#!/usr/bin/env python3
"""Valjer eller skapar en simulator med en viss punktstorlek for designbilderna.

Punktstorleken finns inte i simctl, sa modellnamnen listas i prioritetsordning
per storlek. Finns ingen av dem skapas en simulator av ratt enhetstyp, om
runtimen pa runnern stoder den.

Skriver simulatorns UDID pa stdout och vad som hittades pa stderr.
Avslutskoder: 0 hittad eller skapad, 3 ingen enhetstyp finns (hoppa over
storleken), 1 annat fel.

Anvandning: select_shot_simulator.py 390x844 | 375x667
"""
import json
import subprocess
import sys

SKIP = 3

MODELS = {
    # macos-26 har iPhone 16e, 17, 17 Pro, 17 Pro Max, 17e och Air.
    "390x844": ["iPhone 16e", "iPhone 14", "iPhone 13", "iPhone 12", "iPhone 16", "iPhone 15"],
    "375x667": ["iPhone SE (3rd generation)", "iPhone SE (2nd generation)", "iPhone 8", "iPhone SE"],
}

# Enhetstyper att skapa av, om ingen av modellerna ovan redan finns.
DEVICE_TYPES = {
    "390x844": ["iPhone-16e", "iPhone-14", "iPhone-13", "iPhone-12"],
    "375x667": ["iPhone-SE-3rd-generation", "iPhone-SE-2nd-generation", "iPhone-8"],
}

PREFIX = "com.apple.CoreSimulator.SimDeviceType."


def simctl(*args) -> dict:
    raw = subprocess.check_output(["xcrun", "simctl", *args, "--json"], text=True)
    return json.loads(raw)


def existing() -> dict:
    found = {}
    for _, group in simctl("list", "devices", "available").get("devices", {}).items():
        for device in group:
            if device.get("isAvailable") is False:
                continue
            found.setdefault(device.get("name", ""), device.get("udid"))
    return found


def ios_runtimes() -> list:
    out = []
    for runtime in simctl("list", "runtimes").get("runtimes", []):
        if not runtime.get("isAvailable"):
            continue
        if "iOS" not in (runtime.get("name") or "") and "iOS" not in (runtime.get("platform") or ""):
            continue
        out.append(runtime)
    # Nyaste iOS forst.
    out.sort(key=lambda r: r.get("version", ""), reverse=True)
    return out


def create(size: str) -> str:
    """Skapar en simulator av ratt enhetstyp. Returnerar UDID eller tom strang."""
    wanted = DEVICE_TYPES.get(size, [])
    types = {t.get("identifier"): t.get("name") for t in simctl("list", "devicetypes").get("devicetypes", [])}
    for runtime in ios_runtimes():
        supported = runtime.get("supportedDeviceTypes") or []
        supported_ids = {d.get("identifier") for d in supported}
        for short in wanted:
            identifier = PREFIX + short
            if identifier not in types:
                continue
            # Stoder runtimen inte enhetstypen gar create inte att lita pa.
            if supported_ids and identifier not in supported_ids:
                continue
            name = "TR-shots-%s" % size
            try:
                udid = subprocess.check_output(
                    ["xcrun", "simctl", "create", name, identifier, runtime["identifier"]],
                    text=True,
                ).strip()
            except subprocess.CalledProcessError as error:
                print("# create %s pa %s misslyckades: %s"
                      % (short, runtime.get("name"), error), file=sys.stderr)
                continue
            print("# skapade %s (%s) pa %s -> %s"
                  % (name, short, runtime.get("name"), udid), file=sys.stderr)
            return udid
    return ""


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in MODELS:
        print("Anvandning: select_shot_simulator.py 390x844 | 375x667", file=sys.stderr)
        return 2
    size = sys.argv[1]

    devices = existing()
    print("# tillgangliga: %s" % ", ".join(sorted(devices)), file=sys.stderr)
    for name in MODELS[size]:
        if name in devices:
            print("# %s -> %s (%s)" % (size, name, devices[name]), file=sys.stderr)
            print(devices[name])
            return 0

    print("# ingen fardig simulator for %s, forsoker skapa en" % size, file=sys.stderr)
    udid = create(size)
    if udid:
        print(udid)
        return 0

    print("Ingen enhetstyp for %s finns pa runnern. Storleken hoppas over."
          % size, file=sys.stderr)
    return SKIP


if __name__ == "__main__":
    raise SystemExit(main())
