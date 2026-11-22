#!/usr/bin/env python3
"""Hamtar Apple Developer Team ID via App Store Connect-API:t.

Skriver raden DEVELOPMENT_TEAM=<team> till stdout (for GITHUB_ENV).
All logg gar till stderr. Kraver pyjwt och cryptography.

Teamet lases forst ur certifikatens Organizational Unit, annars ur
TeamIdentifier i en provisioneringsprofil. Hittas inget maste team_id
anges manuellt nar workflowen startas.
"""
import base64
import collections
import json
import os
import plistlib
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com"


def token() -> str:
    import jwt

    key_path = os.environ["ASC_KEY_PATH"]
    with open(key_path) as handle:
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


def get(path: str, bearer: str) -> dict:
    request = urllib.request.Request(
        API + path, headers={"Authorization": "Bearer " + bearer}
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def from_certificates(bearer: str) -> collections.Counter:
    from cryptography import x509
    from cryptography.x509.oid import NameOID

    found: collections.Counter = collections.Counter()
    for item in get("/v1/certificates?limit=200", bearer).get("data", []):
        content = item.get("attributes", {}).get("certificateContent")
        if not content:
            continue
        cert = x509.load_der_x509_certificate(base64.b64decode(content))
        for unit in cert.subject.get_attributes_for_oid(
            NameOID.ORGANIZATIONAL_UNIT_NAME
        ):
            found[unit.value] += 1
    return found


def from_profiles(bearer: str) -> collections.Counter:
    found: collections.Counter = collections.Counter()
    for item in get("/v1/profiles?limit=200", bearer).get("data", []):
        content = item.get("attributes", {}).get("profileContent")
        if not content:
            continue
        blob = base64.b64decode(content)
        start = blob.find(b"<?xml")
        end = blob.find(b"</plist>")
        if start < 0 or end < 0:
            continue
        info = plistlib.loads(blob[start : end + 8])
        for team in info.get("TeamIdentifier", []):
            found[team] += 1
    return found


def main() -> int:
    bearer = token()
    teams: collections.Counter = collections.Counter()
    for source in (from_certificates, from_profiles):
        if teams:
            break
        try:
            teams = source(bearer)
        except urllib.error.HTTPError as error:
            print(
                "# %s gav HTTP %s: %s"
                % (source.__name__, error.code, error.read()[:200]),
                file=sys.stderr,
            )
        except Exception as error:  # noqa: BLE001
            print("# %s misslyckades: %s" % (source.__name__, error), file=sys.stderr)

    if not teams:
        print(
            "Hittade inget Team ID via API-nyckeln. Starta workflowen igen och fyll "
            "i team_id. Det star under Membership details pa developer.apple.com.",
            file=sys.stderr,
        )
        return 1

    team, _ = teams.most_common(1)[0]
    print("# Team ID: %s" % team, file=sys.stderr)
    print("DEVELOPMENT_TEAM=%s" % team)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
