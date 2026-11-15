#!/usr/bin/env python3
"""Check release numbering and verify processing, without submitting for review."""

import base64
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

APP_ID = "6826782065"
API = "https://api.appstoreconnect.apple.com"
PLATFORMS = {"ios": "IOS", "macos": "MAC_OS"}


def release_version():
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$",
                      Path("pubspec.yaml").read_text(), re.MULTILINE)
    if not match:
        raise ValueError("pubspec.yaml must contain version: major.minor.patch+build")
    return match.groups()


def build_number(value):
    parts = tuple(int(part) for part in value.split("."))
    return parts + (0,) * (3 - len(parts))


@contextmanager
def credentials():
    raw = os.environ.get("APP_STORE_CONNECT_PRIVATE_KEY")
    if raw:
        with tempfile.NamedTemporaryFile(dir=os.environ["RUNNER_TEMP"], suffix=".p8") as key:
            key.write(raw.encode())
            key.flush()
            yield {"key_id": os.environ["APP_STORE_CONNECT_KEY_ID"],
                   "issuer_id": os.environ["APP_STORE_CONNECT_ISSUER_ID"],
                   "key_path": key.name}
    else:
        directory = Path(os.environ["RUNNER_TEMP"]) / "apple-release-signing"
        config = json.loads((directory / "config.json").read_text())
        config["key_path"] = str(directory / ("AuthKey_" + config["key_id"] + ".p8"))
        yield config


def encode(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=")


def jwt(config):
    now = int(time.time())
    header = encode(json.dumps({"alg": "ES256", "kid": config["key_id"], "typ": "JWT"}).encode())
    payload = encode(json.dumps({"iss": config["issuer_id"], "iat": now,
                                 "exp": now + 600, "aud": "appstoreconnect-v1"}).encode())
    message = header + b"." + payload
    result = subprocess.run(["openssl", "dgst", "-sha256", "-sign", config["key_path"]],
                            input=message, capture_output=True)
    if result.returncode:
        raise RuntimeError("Could not sign the Apple API authentication token")
    signature = result.stdout
    # OpenSSL returns ASN.1 DER ECDSA; JWT uses the two fixed-width integers.
    position = 2 + (signature[1] & 127) if signature[1] & 128 else 2
    integers = []
    for _ in range(2):
        if signature[position] != 2:
            raise ValueError("Invalid ECDSA signature")
        length = signature[position + 1]
        number = signature[position + 2:position + 2 + length].lstrip(b"\0")
        if len(number) > 32:
            raise ValueError("Expected a P-256 API key")
        integers.append(number.rjust(32, b"\0"))
        position += length + 2
    return (message + b"." + encode(b"".join(integers))).decode()


def get_json(url, config):
    if not url.startswith(API + "/"):
        raise ValueError("Unexpected Apple API host")
    for attempt in range(4):
        request = Request(url, headers={"Authorization": "Bearer " + jwt(config)})
        try:
            with urlopen(request, timeout=45) as response:
                return json.load(response)
        except HTTPError as error:
            if error.code in (429, 500, 502, 503, 504) and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            # Authentication headers and tokens must never appear in errors.
            raise RuntimeError(f"Apple API request failed: HTTP {error.code}") from None
        except URLError:
            if attempt == 3:
                raise RuntimeError("Could not reach the Apple API") from None
            time.sleep(5 * (attempt + 1))


def builds(config):
    query = urlencode({"filter[app]": APP_ID, "include": "preReleaseVersion", "limit": 200})
    url = API + "/v1/builds?" + query
    records = []
    while url:
        page = get_json(url, config)
        versions = {item["id"]: item["attributes"] for item in page.get("included", [])
                    if item["type"] == "preReleaseVersions"}
        for item in page["data"]:
            related = item["relationships"]["preReleaseVersion"]["data"]
            release = versions[related["id"]]
            records.append({**item["attributes"], "id": item["id"],
                            "version": release["version"], "platform": release["platform"],
                            "build": item["attributes"]["version"]})
        url = page.get("links", {}).get("next")
    return records


def check(records, version, number):
    errors = []
    if os.environ.get("GITHUB_REF_TYPE") == "tag" and os.environ["GITHUB_REF_NAME"] != "v" + version:
        errors.append("The release tag must match pubspec.yaml: v" + version)
    for platform in PLATFORMS.values():
        previous = [item for item in records if item["platform"] == platform]
        for item in previous:
            if item["version"] == version and build_number(item["build"]) == build_number(number):
                errors.append(f"{platform} {version} ({number}) already exists on Apple")
        highest = max((item["build"] for item in previous), key=build_number, default=None)
        print(f"{platform}: highest uploaded build is {highest or 'none'}; requested {version} ({number})")
        if platform == "MAC_OS" and highest and build_number(number) <= build_number(highest):
            errors.append(f"macOS build number must be greater than {highest}; update pubspec.yaml")
    if errors:
        raise ValueError("; ".join(errors))


def wait(config, platform, version, number):
    deadline = time.monotonic() + 1200
    last_state = None
    while time.monotonic() < deadline:
        matches = [item for item in builds(config) if item["platform"] == PLATFORMS[platform]
                   and item["version"] == version and build_number(item["build"]) == build_number(number)]
        state = matches[0]["processingState"] if matches else "AWAITING_APPLE_RECORD"
        if state != last_state:
            print(f"{platform}: {version} ({number}) Apple processing: {state}", flush=True)
            last_state = state
        if state == "VALID":
            print(f"Verified build in App Store Connect: {matches[0]['id']}")
            return
        if state in ("FAILED", "INVALID"):
            raise RuntimeError(f"Apple processing failed for {platform}: {state}")
        time.sleep(20)
    raise RuntimeError("Upload completed, but Apple processing has not finished after 20 minutes")


def main():
    version, number = release_version()
    with credentials() as config:
        if sys.argv[1:] == ["check"]:
            check(builds(config), version, number)
        elif len(sys.argv) == 3 and sys.argv[1] == "wait" and sys.argv[2] in PLATFORMS:
            wait(config, sys.argv[2], version, number)
        else:
            raise ValueError("Usage: app_store_connect.py check, or wait ios|macos")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, KeyError) as error:
        print(f"App Store Connect: {error}", file=sys.stderr)
        sys.exit(1)
