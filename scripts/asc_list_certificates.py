#!/usr/bin/env python3
"""Listar kontots certifikat via App Store Connect-API:t.

Bara lasning. Inget certifikat skapas och inget aterkallas: det ar ett
beslut for kontots agare och gors i Developer-portalen.

Nar Apples tak for Apple Development ar natt svarar
xcodebuild med "Choose a certificate to revoke" och arkiveringen faller.
Steget skriver darfor ut vad som finns, sa att loggen visar exakt vilka
certifikat som gar att aterkalla.

Avslutar alltid med 0: listningen ar en hjalp, inte ett krav. Det riktiga
felet kommer fran xcodebuild.

Kraver pyjwt och cryptography samt ASC_KEY_PATH, ASC_KEY_ID och
ASC_ISSUER_ID i miljon.

Anvandning: asc_list_certificates.py
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com"

# Varje korning sker pa en ny runner utan den privata nyckeln till kontots
# befintliga certifikat, sa automatisk signering skapar ett nytt vid varje
# arkivering. De heter "Created via API" och samlas pa hog tills Apples tak
# ar natt. Taket star inte dokumenterat som en siffra, sa skriptet pastar
# ingen grans: det raknar och sager till nar hogen blivit stor.
VARNA_VID = 10


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


def call(path: str, bearer: str) -> dict:
    request = urllib.request.Request(
        API + path, headers={"Authorization": "Bearer " + bearer}, method="GET"
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        raw = response.read()
    return json.loads(raw) if raw else {}


def main() -> int:
    try:
        bearer = token()
        query = urllib.parse.urlencode({"limit": 200})
        items = call("/v1/certificates?" + query, bearer).get("data", [])
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:400]
        print("Kunde inte lasa certifikaten: HTTP %s %s" % (error.code, detail))
        return 0
    except Exception as error:  # noqa: BLE001 - listningen far aldrig falla korningen
        print("Kunde inte lasa certifikaten: %s" % error)
        return 0

    if not items:
        print("Kontot har inga certifikat.")
        return 0

    per_type: dict[str, int] = {}
    print("Certifikat pa kontot (%d):" % len(items))
    print("")
    for item in items:
        a = item.get("attributes", {})
        kind = str(a.get("certificateType", "?"))
        per_type[kind] = per_type.get(kind, 0) + 1
        print("  %-22s %-38s gar ut %s" % (
            kind,
            str(a.get("name", "?"))[:38],
            str(a.get("expirationDate", "?"))[:10],
        ))
        print("    serienummer %s  id %s" % (
            a.get("serialNumber", "?"), item.get("id", "?")
        ))
    print("")

    via_api = sum(
        1 for item in items
        if str(item.get("attributes", {}).get("certificateType", "")) == "DEVELOPMENT"
        and "Created via API" in str(item.get("attributes", {}).get("name", ""))
    )
    for kind, count in sorted(per_type.items()):
        print("  %-22s %d" % (kind, count))

    if via_api >= VARNA_VID:
        print("")
        print("::warning::%d av certifikaten ar av typen DEVELOPMENT och heter "
              "\"Created via API\", alltsa skapade av den har arbetsfloden. "
              "Varje korning lagger till ett till. Nar Apples tak ar natt "
              "faller arkiveringen med \"Choose a certificate to revoke\". "
              "De aterkallas i Developer-portalen: "
              "https://developer.apple.com/account/resources/certificates/list"
              % via_api)
    return 0


if __name__ == "__main__":
    sys.exit(main())
