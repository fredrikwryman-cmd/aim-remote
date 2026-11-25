#!/usr/bin/env python3
"""Aterkallar de certifikat som molnbyggena har skapat.

Varje korning av adhoc.yml och testflight.yml sker pa en ny runner utan den
privata nyckeln till kontots befintliga certifikat, sa automatisk signering
skapar ett nytt Apple Development-certifikat varje gang. De heter alltid
exakt "Apple Development: Created via API" och samlas pa hog tills Apples
tak ar natt, varefter arkiveringen faller med "Choose a certificate to
revoke".

Skriptet aterkallar ENDAST certifikat som bade har typen DEVELOPMENT och
namnet exakt NAMN nedan. Allt annat lamnas, och det galler sarskilt
distributionscertifikat: de ar skapade av en manniska och gar inte att
ateruppratta utan atkomst till nyckeln.

Lagen:
  --spara-id FIL   skriver ut id:na pa de certifikat som matchar just nu,
                   ett per rad, och aterkallar ingenting. Anvands fore
                   arkiveringen sa att stadsteget efterat vet vilka som
                   redan fanns.
  --utom-fil FIL   aterkallar bara de matchande certifikat vars id INTE
                   star i FIL, alltsa de som tillkom under korningen.
  --torrkor        visar vad som skulle aterkallas, gor inget.
  utan flaggor     aterkallar alla matchande certifikat.

Kraver pyjwt och cryptography samt ASC_KEY_PATH, ASC_KEY_ID och
ASC_ISSUER_ID i miljon.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com"

# Namnet maste stamma tecken for tecken. Xcode satter det sjalv nar det
# skapar ett certifikat via API-nyckeln; manuellt skapade heter nagot annat.
NAMN = "Apple Development: Created via API"
TYP = "DEVELOPMENT"


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


def call(path: str, bearer: str, method: str = "GET") -> dict:
    request = urllib.request.Request(
        API + path, headers={"Authorization": "Bearer " + bearer}, method=method
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        raw = response.read()
    return json.loads(raw) if raw else {}


def certifikat(bearer: str) -> list:
    query = urllib.parse.urlencode({"limit": 200})
    return call("/v1/certificates?" + query, bearer).get("data", [])


def matchar(item: dict) -> bool:
    a = item.get("attributes", {})
    return str(a.get("certificateType", "")) == TYP and str(a.get("name", "")) == NAMN


def main(argv: list) -> int:
    spara = None
    utom_fil = None
    torrkor = False
    rest = list(argv)
    while rest:
        flagga = rest.pop(0)
        if flagga == "--spara-id":
            spara = rest.pop(0)
        elif flagga == "--utom-fil":
            utom_fil = rest.pop(0)
        elif flagga == "--torrkor":
            torrkor = True
        else:
            print("Okand flagga: %s" % flagga, file=sys.stderr)
            return 2

    bearer = token()
    alla = certifikat(bearer)
    traffar = [item for item in alla if matchar(item)]

    if spara is not None:
        with open(spara, "w") as handle:
            for item in traffar:
                handle.write(str(item.get("id", "")) + "\n")
        print("Sparade %d id:n (%s) i %s" % (len(traffar), NAMN, spara))
        return 0

    redan = set()
    if utom_fil is not None:
        try:
            with open(utom_fil) as handle:
                redan = {rad.strip() for rad in handle if rad.strip()}
        except FileNotFoundError:
            # Utan listan vet vi inte vilka som fanns fore, och da aterkallas
            # inget: hellre en vaxande hog an ett borttaget certifikat.
            print("Hittade inte %s, aterkallar inget." % utom_fil)
            return 0
        traffar = [item for item in traffar if str(item.get("id", "")) not in redan]

    lamnade = [item for item in alla if item not in traffar]
    print("Certifikat pa kontot: %d" % len(alla))
    print("")
    print("Lamnas (%d):" % len(lamnade))
    for item in lamnade:
        a = item.get("attributes", {})
        print("  %-16s %s" % (a.get("certificateType", "?"), a.get("name", "?")))
    print("")
    if not traffar:
        print("Inget att aterkalla.")
        return 0

    print("Aterkallas (%d):" % len(traffar))
    for item in traffar:
        a = item.get("attributes", {})
        print("  %s  %s  %s" % (
            item.get("id", "?"), a.get("name", "?"), a.get("serialNumber", "?")
        ))
    print("")

    if torrkor:
        print("Torrkorning: inget aterkallades.")
        return 0

    fel = 0
    for item in traffar:
        ident = str(item.get("id", ""))
        # Dubbelkoll mot namn och typ direkt fore raderingen: listan kan vara
        # gammal, och en felaktig DELETE gar inte att angra.
        if not matchar(item):
            print("Hoppar over %s: matchar inte langre." % ident)
            continue
        try:
            call("/v1/certificates/" + ident, bearer, method="DELETE")
            print("Aterkallade %s" % ident)
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:300]
            print("Kunde inte aterkalla %s: HTTP %s %s" % (ident, error.code, detail))
            fel += 1
        except Exception as error:  # noqa: BLE001
            print("Kunde inte aterkalla %s: %s" % (ident, error))
            fel += 1

    kvar = certifikat(bearer)
    print("")
    print("Certifikat pa kontot efterat: %d" % len(kvar))
    for item in kvar:
        a = item.get("attributes", {})
        print("  %-16s %s" % (a.get("certificateType", "?"), a.get("name", "?")))
    return 1 if fel else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
