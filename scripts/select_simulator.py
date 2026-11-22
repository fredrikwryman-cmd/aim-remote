#!/usr/bin/env python3
"""Valjer en tillganglig iPhone-simulator pa runnern.

Skriver raden SIMULATOR_ID=<udid> pa stdout (for GITHUB_ENV) och vilka
enheter som fanns pa stderr. Inget modellnamn ar hardkodat: nyaste vanliga
iPhone valjs, annars nyaste iPhone av nagot slag, annars den forsta som
finns.
"""
import json
import re
import subprocess
import sys

VARIANT = re.compile(r"\b(pro|plus|max|mini|se|air)\b", re.IGNORECASE)
NUMBER = re.compile(r"iPhone\s+(\d+)")


def devices() -> list:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "--json"], text=True
    )
    data = json.loads(raw)
    found = []
    for runtime, group in data.get("devices", {}).items():
        for device in group:
            if "iPhone" not in device.get("name", ""):
                continue
            if device.get("isAvailable") is False:
                continue
            device["runtime"] = runtime
            found.append(device)
    return found


def rank(device: dict) -> tuple:
    name = device["name"]
    match = NUMBER.search(name)
    number = int(match.group(1)) if match else 0
    plain = 0 if VARIANT.search(name) else 1
    return (plain, number, name)


def main() -> int:
    try:
        found = devices()
    except Exception as error:  # noqa: BLE001
        print("Kunde inte lista simulatorer: %s" % error, file=sys.stderr)
        return 1
    if not found:
        print("Ingen tillganglig iPhone-simulator pa runnern.", file=sys.stderr)
        return 1

    for device in sorted(found, key=rank, reverse=True):
        print("# %-22s %s" % (device["name"], device["udid"]), file=sys.stderr)
    chosen = max(found, key=rank)
    print(
        "# vald: %s (%s)" % (chosen["name"], chosen.get("runtime", "")),
        file=sys.stderr,
    )
    print("SIMULATOR_ID=%s" % chosen["udid"])
    print("SIMULATOR_NAME=%s" % chosen["name"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
