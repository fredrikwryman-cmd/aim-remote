#!/usr/bin/env python3
"""Registrerar en iPhone for ad hoc-signering via App Store Connect-API:t.

Steget ar tankt att kunna koras om: finns UDID:t redan gors ingen ny
registrering, och ar enheten avstangd slas den pa igen. Kraver pyjwt och
cryptography samt ASC_KEY_PATH, ASC_KEY_ID och ASC_ISSUER_ID i miljon.

Anvandning: asc_register_device.py <udid> <namn> [plattform]
Plattform ar IOS om inget anges.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com"


def token() -> str:
    import jwt

    with open(os.environ["ASC_KEY_PATH"]) as handle:
        key = handle.read()
    now = int(time.time())
    return jwt.encode(
        {
            "iss": os.environ["ASC_ISSUER_ID"],
            "iat": now,
            "exp": now + 600,
            "aud": "appstoreconnect-v1",
        },
        key,
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def call(method: str, path: str, bearer: str, body=None) -> dict:
    data = None
    headers = {"Authorization": "Bearer " + bearer}
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    with urllib.request.urlopen(request, timeout=60) as response:
        raw = response.read()
    return json.loads(raw) if raw else {}


def find(udid: str, bearer: str):
    query = urllib.parse.urlencode({"filter[udid]": udid, "limit": 200})
    for item in call("GET", "/v1/devices?" + query, bearer).get("data", []):
        attributes = item.get("attributes", {})
        if str(attributes.get("udid", "")).lower() == udid.lower():
            return item
    return None


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print(
            "Anvandning: asc_register_device.py <udid> <namn> [plattform]",
            file=sys.stderr,
        )
        return 2
    udid = sys.argv[1].strip()
    name = sys.argv[2].strip()
    platform = (sys.argv[3].strip() if len(sys.argv) == 4 else "IOS").upper()
    if not udid or not name:
        print("UDID och namn maste anges.", file=sys.stderr)
        return 1

    bearer = token()

    existing = find(udid, bearer)
    if existing is not None:
        attributes = existing.get("attributes", {})
        status = str(attributes.get("status", "")).upper()
        print(
            "Enheten finns redan: %s (%s, status %s)"
            % (attributes.get("name"), attributes.get("udid"), status or "okand")
        )
        if status == "DISABLED":
            print("Statusen ar DISABLED. Slar pa enheten igen.")
            call(
                "PATCH",
                "/v1/devices/" + existing["id"],
                bearer,
                {
                    "data": {
                        "type": "devices",
                        "id": existing["id"],
                        "attributes": {"status": "ENABLED"},
                    }
                },
            )
            print("Enheten ar nu ENABLED.")
        return 0

    print("Registrerar %s (%s) som %s." % (name, udid, platform))
    try:
        created = call(
            "POST",
            "/v1/devices",
            bearer,
            {
                "data": {
                    "type": "devices",
                    "attributes": {"name": name, "platform": platform, "udid": udid},
                }
            },
        )
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:600]
        if error.code == 409:
            # Apple svarar 409 nar UDID:t redan ar upptaget. Steget ska kunna
            # koras om, sa det raknas som klart.
            print("# HTTP 409 fran Apple: %s" % detail, file=sys.stderr)
            print("UDID:t ar redan registrerat hos Apple. Gar vidare.")
            return 0
        print("HTTP %s fran Apple: %s" % (error.code, detail), file=sys.stderr)
        return 1

    attributes = created.get("data", {}).get("attributes", {})
    print(
        "Registrerad: %s (%s, status %s)"
        % (
            attributes.get("name", name),
            attributes.get("udid", udid),
            attributes.get("status", "okand"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
