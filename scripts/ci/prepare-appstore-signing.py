#!/usr/bin/env python3
"""Create App Store signing assets for the TestFlight archive.

Uses the App Store Connect API key already installed for xcodebuild.
Manual signing needs a local Apple Distribution identity and an App Store
profile per bundle id. Those profiles are not tied to device UDIDs.

The distribution private key stays on this runner. Certificates whose subject
is the CI name below are revoked before a new one is created, so repeats do
not pile up against Apple's certificate limit. Other certificates are left
alone.
"""

from __future__ import annotations

import base64
import json
import os
import plistlib
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.appstoreconnect.apple.com"
CI_CERT_CN = "GitHub Actions Codex Reset Tracker"
# Created on a runner whose keychain rejected the PKCS#12, so the private key is gone.
ORPHAN_CERTIFICATE_IDS = ("T67YA5RL8R",)
GROUP = "group.com.arnar111.codexresettracker"
BUNDLES = (
    ("com.arnar111.codexresettracker", "Codex Reset Tracker", ("PUSH_NOTIFICATIONS", "APP_GROUPS")),
    ("com.arnar111.codexresettracker.widget", "Codex Reset Tracker Widget", ("APP_GROUPS",)),
    ("com.arnar111.codexresettracker.notification", "Codex Reset Tracker Notification", ()),
)


def fail(message: str) -> None:
    print(f"::error::{message}")
    raise SystemExit(1)


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def der_ecdsa_to_raw(der: bytes) -> bytes:
    if not der or der[0] != 0x30:
        fail("Could not sign the App Store Connect token.")
    index = 2
    if der[1] & 0x80:
        index = 2 + (der[1] & 0x7F)
    if der[index] != 0x02:
        fail("Could not sign the App Store Connect token.")
    index += 1
    rlen = der[index]
    index += 1
    r = der[index : index + rlen]
    index += rlen
    if der[index] != 0x02:
        fail("Could not sign the App Store Connect token.")
    index += 1
    slen = der[index]
    index += 1
    s = der[index : index + slen]

    def trim(part: bytes) -> bytes:
        part = part.lstrip(b"\x00")
        if len(part) > 32:
            fail("Could not sign the App Store Connect token.")
        return part.rjust(32, b"\x00")

    return trim(r) + trim(s)


def make_token(key_id: str, issuer_id: str, key_path: str) -> str:
    now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}, separators=(",", ":")).encode())
    payload = b64url(
        json.dumps(
            {"iss": issuer_id, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
            separators=(",", ":"),
        ).encode()
    )
    signing_input = f"{header}.{payload}".encode()
    signed = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input,
        capture_output=True,
        check=False,
    )
    if signed.returncode != 0:
        fail("Could not sign the App Store Connect token with ASC_PRIVATE_KEY.")
    return f"{header}.{payload}.{b64url(der_ecdsa_to_raw(signed.stdout))}"


def api(token: str, method: str, path: str, body: dict | None = None) -> tuple[int, dict]:
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(API + path, data=data, method=method)
    request.add_header("Authorization", f"Bearer {token}")
    request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            parsed = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            parsed = {"raw": raw.decode("utf-8", "replace")[:500]}
        return error.code, parsed


def apple_errors(payload: dict) -> str:
    errors = payload.get("errors") if isinstance(payload, dict) else None
    if not errors:
        return json.dumps(payload)[:500]
    parts = []
    for item in errors:
        parts.append(f"{item.get('status')} {item.get('code')}: {item.get('title')} {item.get('detail', '')}".strip())
    return "; ".join(parts)


def raise_for_agreement(status: int, payload: dict) -> None:
    text = apple_errors(payload).lower()
    if status == 403 and ("agreement" in text or "license" in text):
        fail(
            "Apple has not accepted the latest developer agreement for this account. "
            "Sign in at https://developer.apple.com/account or App Store Connect and accept it, then re-run iOS TestFlight. "
            "No device registration is required."
        )


def ensure_bundle(token: str, bundle_id: str, name: str) -> str:
    query = urllib.parse.urlencode({"filter[identifier]": bundle_id, "limit": 5})
    status, payload = api(token, "GET", f"/v1/bundleIds?{query}")
    raise_for_agreement(status, payload)
    if status != 200:
        fail(f"Could not list bundle id {bundle_id}: {apple_errors(payload)}")
    for item in payload.get("data", []):
        if item.get("attributes", {}).get("identifier") == bundle_id:
            print(f"Bundle id exists: {bundle_id}")
            return item["id"]
    status, payload = api(
        token,
        "POST",
        "/v1/bundleIds",
        {
            "data": {
                "type": "bundleIds",
                "attributes": {"name": name, "identifier": bundle_id, "platform": "IOS"},
            }
        },
    )
    if status not in (200, 201):
        raise_for_agreement(status, payload)
        fail(f"Could not create bundle id {bundle_id}: {apple_errors(payload)}")
    print(f"Created bundle id: {bundle_id}")
    return payload["data"]["id"]


def capability_types(token: str, resource_id: str) -> set[str]:
    status, payload = api(token, "GET", f"/v1/bundleIds/{resource_id}/bundleIdCapabilities")
    if status != 200:
        print(f"::warning::Could not list capabilities for {resource_id}: {apple_errors(payload)}")
        return set()
    return {item.get("attributes", {}).get("capabilityType", "") for item in payload.get("data", [])}


def ensure_capability(token: str, resource_id: str, capability: str, present: set[str]) -> None:
    if capability in present:
        return
    attributes: dict = {"capabilityType": capability}
    if capability == "APP_GROUPS":
        attributes["settings"] = [
            {
                "key": "APP_GROUPS",
                "options": [{"key": GROUP, "enabled": True}],
            }
        ]
    status, payload = api(
        token,
        "POST",
        "/v1/bundleIdCapabilities",
        {
            "data": {
                "type": "bundleIdCapabilities",
                "attributes": attributes,
                "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": resource_id}}},
            }
        },
    )
    if status in (200, 201, 409):
        print(f"Capability {capability} enabled")
        return
    # The capability may already be on, or App Groups may already be configured in the portal.
    print(f"::warning::Could not enable {capability}: {apple_errors(payload)}")


def subject_of(certificate_b64: str, work: Path) -> str:
    der = work / "inspect.cer"
    der.write_bytes(base64.b64decode(certificate_b64))
    result = subprocess.run(
        ["openssl", "x509", "-inform", "DER", "-in", str(der), "-noout", "-subject"],
        capture_output=True,
        text=True,
        check=False,
    )
    der.unlink(missing_ok=True)
    return result.stdout or ""


def revoke_certificate(token: str, certificate_id: str) -> None:
    status, _payload = api(token, "GET", f"/v1/certificates/{certificate_id}")
    if status == 404:
        return
    if status != 200:
        return
    print(f"Revoking unused distribution certificate {certificate_id}")
    deleted, body = api(token, "DELETE", f"/v1/certificates/{certificate_id}")
    if deleted not in (200, 204):
        fail(f"Could not revoke certificate {certificate_id}: {apple_errors(body)}")


def ensure_distribution_cert(token: str, work: Path) -> str:
    for certificate_id in ORPHAN_CERTIFICATE_IDS:
        revoke_certificate(token, certificate_id)
    status, payload = api(token, "GET", "/v1/certificates?filter[certificateType]=DISTRIBUTION&limit=20")
    raise_for_agreement(status, payload)
    if status != 200:
        fail(f"Could not list distribution certificates: {apple_errors(payload)}")
    for item in payload.get("data", []):
        content = item.get("attributes", {}).get("certificateContent")
        if content and CI_CERT_CN in subject_of(content, work):
            print(f"Revoking previous CI distribution certificate {item['id']}")
            deleted, body = api(token, "DELETE", f"/v1/certificates/{item['id']}")
            if deleted not in (200, 204):
                fail(f"Could not revoke previous CI certificate: {apple_errors(body)}")

    key = work / "distribution.key"
    csr = work / "distribution.csr"
    created = subprocess.run(
        [
            "openssl",
            "req",
            "-new",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            str(key),
            "-out",
            str(csr),
            "-subj",
            f"/CN={CI_CERT_CN}",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if created.returncode != 0:
        fail("Could not create a certificate signing request.")
    status, payload = api(
        token,
        "POST",
        "/v1/certificates",
        {
            "data": {
                "type": "certificates",
                "attributes": {
                    "certificateType": "DISTRIBUTION",
                    "csrContent": csr.read_text(),
                },
            }
        },
    )
    if status not in (200, 201):
        text = apple_errors(payload)
        if "limit" in text.lower() or "maximum" in text.lower() or "ENTITY_ERROR" in text:
            fail(
                "Apple refused a new Apple Distribution certificate (the account is at its certificate limit). "
                "Revoke an unused Apple Distribution certificate at https://developer.apple.com/account/resources/certificates/list "
                "and re-run iOS TestFlight. Do not register devices. "
                f"Apple said: {text}"
            )
        raise_for_agreement(status, payload)
        fail(f"Could not create an Apple Distribution certificate: {text}")
    cert_b64 = payload["data"]["attributes"]["certificateContent"]
    cert_id = payload["data"]["id"]
    cer = work / "distribution.cer"
    cer.write_bytes(base64.b64decode(cert_b64))
    print(f"Created Apple Distribution certificate {cert_id}")
    print(subject_of(cert_b64, work).strip())
    return cert_id


def run_secret(args: list[str], secret: str) -> None:
    result = subprocess.run(args, capture_output=True, text=True, check=False)
    if result.returncode == 0:
        return
    shown = " ".join("***" if part == secret else part for part in args)
    detail = (result.stderr or result.stdout or "").strip()
    fail(f"{shown} failed: {detail}")


def install_identity(work: Path) -> None:
    password = base64.urlsafe_b64encode(os.urandom(18)).decode("ascii")
    pem = work / "distribution.pem"
    p12 = work / "distribution.p12"
    converted = subprocess.run(
        ["openssl", "x509", "-inform", "DER", "-in", str(work / "distribution.cer"), "-out", str(pem)],
        capture_output=True,
        text=True,
        check=False,
    )
    if converted.returncode != 0:
        fail("Could not read the distribution certificate.")
    # OpenSSL 3's default PKCS#12 uses PBES2. macOS `security import` reports that as a bad MAC.
    export_base = [
        "openssl",
        "pkcs12",
        "-export",
        "-inkey",
        str(work / "distribution.key"),
        "-in",
        str(pem),
        "-out",
        str(p12),
        "-passout",
        f"pass:{password}",
    ]
    exported = subprocess.run(
        export_base[:2] + ["-legacy"] + export_base[2:],
        capture_output=True,
        text=True,
        check=False,
    )
    if exported.returncode != 0:
        exported = subprocess.run(
            export_base[:2]
            + ["-keypbe", "PBE-SHA1-3DES", "-certpbe", "PBE-SHA1-3DES", "-macalg", "SHA1"]
            + export_base[2:],
            capture_output=True,
            text=True,
            check=False,
        )
    if exported.returncode != 0:
        fail("Could not package the distribution identity for the macOS keychain.")
    keychain = work / "ci.keychain-db"
    run_secret(["security", "create-keychain", "-p", password, str(keychain)], password)
    run_secret(["security", "set-keychain-settings", "-lut", "21600", str(keychain)], password)
    run_secret(["security", "unlock-keychain", "-p", password, str(keychain)], password)
    listed = subprocess.run(["security", "list-keychains", "-d", "user"], capture_output=True, text=True, check=False)
    if listed.returncode != 0:
        fail("Could not read the login keychains.")
    existing = [part.strip().strip('"') for part in listed.stdout.splitlines() if part.strip()]
    run_secret(["security", "list-keychains", "-d", "user", "-s", str(keychain), *existing], password)
    run_secret(["security", "default-keychain", "-s", str(keychain)], password)
    run_secret(
        [
            "security",
            "import",
            str(p12),
            "-k",
            str(keychain),
            "-P",
            password,
            "-T",
            "/usr/bin/codesign",
            "-T",
            "/usr/bin/security",
        ],
        password,
    )
    run_secret(
        ["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", password, str(keychain)],
        password,
    )
    identities = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning", str(keychain)],
        capture_output=True,
        text=True,
        check=False,
    )
    print(identities.stdout)
    if "Apple Distribution" not in identities.stdout:
        fail("The distribution certificate was created but is not in the keychain as Apple Distribution.")
    p12.unlink(missing_ok=True)
    (work / "distribution.key").unlink(missing_ok=True)


def decode_profile(path: Path, work: Path) -> dict:
    plist_path = work / "profile.plist"
    for command in (
        ["openssl", "cms", "-inform", "DER", "-verify", "-noverify", "-in", str(path), "-out", str(plist_path)],
        ["openssl", "smime", "-inform", "DER", "-verify", "-noverify", "-in", str(path), "-out", str(plist_path)],
    ):
        subprocess.run(command, capture_output=True, check=False)
        if plist_path.exists() and plist_path.stat().st_size > 0:
            with plist_path.open("rb") as handle:
                return plistlib.load(handle)
    fail(f"Could not read provisioning profile {path.name}")
    return {}


def ensure_profile(token: str, bundle_resource_id: str, bundle_id: str, certificate_id: str, work: Path) -> None:
    name = f"{bundle_id} AppStore"
    query = urllib.parse.urlencode({"filter[name]": name, "limit": 5})
    status, payload = api(token, "GET", f"/v1/profiles?{query}")
    if status == 200:
        for item in payload.get("data", []):
            if item.get("attributes", {}).get("name") == name:
                print(f"Replacing App Store profile {name}")
                deleted, body = api(token, "DELETE", f"/v1/profiles/{item['id']}")
                if deleted not in (200, 204):
                    fail(f"Could not replace App Store profile {name}: {apple_errors(body)}")
    status, payload = api(
        token,
        "POST",
        "/v1/profiles",
        {
            "data": {
                "type": "profiles",
                "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
                "relationships": {
                    "bundleId": {"data": {"type": "bundleIds", "id": bundle_resource_id}},
                    "certificates": {"data": [{"type": "certificates", "id": certificate_id}]},
                },
            }
        },
    )
    if status not in (200, 201):
        raise_for_agreement(status, payload)
        fail(
            f"Could not create an App Store profile for {bundle_id}: {apple_errors(payload)}. "
            "App Store profiles do not use device UDIDs. If this mentions a capability, enable Push on the app id "
            f"and the App Group {GROUP} on the app and widget ids in the developer portal."
        )
    raw = base64.b64decode(payload["data"]["attributes"]["profileContent"])
    provisional = work / f"{bundle_id}.mobileprovision"
    provisional.write_bytes(raw)
    decoded = decode_profile(provisional, work)
    uuid = decoded.get("UUID")
    if not uuid:
        fail(f"App Store profile for {bundle_id} has no UUID.")
    destination_dir = Path.home() / "Library/MobileDevice/Provisioning Profiles"
    destination_dir.mkdir(parents=True, exist_ok=True)
    target = destination_dir / f"{uuid}.mobileprovision"
    target.write_bytes(raw)
    print(f"Installed App Store profile {name} ({uuid})")


def main() -> None:
    key_id = os.environ.get("ASC_KEY_ID", "")
    issuer = os.environ.get("ASC_ISSUER_ID", "")
    key_path = os.environ.get("AUTH_KEY_PATH", "")
    if not key_id or not issuer or not key_path:
        fail("ASC_KEY_ID, ASC_ISSUER_ID, and AUTH_KEY_PATH are required.")
    work = Path("build/signing")
    work.mkdir(parents=True, exist_ok=True)
    token = make_token(key_id, issuer, key_path)
    certificate_id = ""
    for bundle_id, name, capabilities in BUNDLES:
        resource_id = ensure_bundle(token, bundle_id, name)
        present = capability_types(token, resource_id)
        for capability in capabilities:
            ensure_capability(token, resource_id, capability, present)
        if not certificate_id:
            certificate_id = ensure_distribution_cert(token, work)
            install_identity(work)
        ensure_profile(token, resource_id, bundle_id, certificate_id, work)
    print("App Store signing assets are ready. No devices were registered.")


if __name__ == "__main__":
    main()
