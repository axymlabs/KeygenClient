#!/usr/bin/env python3
"""Install only this build's Apple credentials into a temporary runner keychain."""

import base64
import json
import os
from pathlib import Path
import plistlib
import secrets
import shlex
import shutil
import subprocess
import sys


def run(args, **kwargs):
    result = subprocess.run(args, capture_output=True, **kwargs)
    if result.returncode:
        # Arguments can contain passwords. Never include them in exceptions.
        raise RuntimeError(f"{Path(args[0]).name} {args[1]} failed (exit {result.returncode})")
    return result.stdout


def secret(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError(f"Missing GitHub Actions secret: {name}")
    return value


def write_private(path, contents):
    # Apple signing tools require credential files. Restrict permissions when
    # creating them, before the first byte is written, inside the private runner
    # directory; cleanup removes them after either success or failure.
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    os.fchmod(descriptor, 0o600)
    with os.fdopen(descriptor, "wb") as handle:
        handle.write(contents)


def validate():
    certificate = base64.b64decode(secret("APPLE_SIGNING_CERTIFICATE_BASE64"), validate=True)
    if len(certificate) < 500:
        raise ValueError("The signing certificate is empty or incomplete")
    secret("APPLE_SIGNING_CERTIFICATE_PASSWORD")
    for name in ("APP_STORE_CONNECT_PRIVATE_KEY", "APP_STORE_CONNECT_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID"):
        secret(name)
    args = ["openssl", "pkcs12", "-noout", "-passin", "env:APPLE_SIGNING_CERTIFICATE_PASSWORD"]
    result = subprocess.run(args, input=certificate, capture_output=True)
    if result.returncode:
        # OpenSSL 3 requires its legacy provider for older PKCS12 exports.
        result = subprocess.run(args + ["-legacy"], input=certificate, capture_output=True)
    if result.returncode:
        raise ValueError("The signing certificate or export password is invalid")
    print("Validated the shared Apple signing certificate")
    return certificate


def install(directory, platform):
    if platform not in ("ios", "macos"):
        raise ValueError("Expected ios or macos")
    certificate = validate()
    certificate_password = secret("APPLE_SIGNING_CERTIFICATE_PASSWORD")
    profile = base64.b64decode(os.environ.get("BUILD_PROFILE_BASE64", ""), validate=True)
    api_key = secret("APP_STORE_CONNECT_PRIVATE_KEY")
    key_id = secret("APP_STORE_CONNECT_KEY_ID")
    issuer_id = secret("APP_STORE_CONNECT_ISSUER_ID")
    directory.mkdir(mode=0o700)
    certificate_path = directory / "certificate.p12"
    profile_path = directory / "profile"
    keychain_path = directory / "build.keychain-db"
    config_path = directory / "config.json"
    config = {"key_id": key_id, "issuer_id": issuer_id, "profiles": []}
    write_private(config_path, json.dumps(config).encode())
    write_private(certificate_path, certificate)
    write_private(profile_path, profile)
    write_private(directory / ("AuthKey_" + key_id + ".p8"), (api_key + "\n").encode())
    info = None
    if profile:
        info = plistlib.loads(run(["security", "cms", "-D", "-i", str(profile_path)]))
        entitlements = info.get("Entitlements", {})
        app_id = entitlements.get("application-identifier", entitlements.get("com.apple.application-identifier"))
        if app_id != "27K26BJN5H.com.axymlabs.keygenapp":
            raise ValueError("The provisioning profile does not belong to this app")
        expected_platform = "iOS" if platform == "ios" else "OSX"
        if expected_platform not in info.get("Platform", []):
            raise ValueError("The provisioning profile is for the wrong platform")
    keychain_password = secrets.token_urlsafe(40)
    run(["security", "create-keychain", "-p", keychain_password, str(keychain_path)])
    run(["security", "set-keychain-settings", "-lut", "21600", str(keychain_path)])
    run(["security", "unlock-keychain", "-p", keychain_password, str(keychain_path)])
    run(["security", "import", str(certificate_path), "-P", certificate_password,
         "-k", str(keychain_path), "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"])
    run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:",
         "-s", "-k", keychain_password, str(keychain_path)])
    previous = shlex.split(run(["security", "list-keychains", "-d", "user"]).decode())
    run(["security", "list-keychains", "-d", "user", "-s", str(keychain_path), *previous])
    certificate_path.unlink()
    if info:
        suffix = ".mobileprovision" if platform == "ios" else ".provisionprofile"
        for relative in ("Library/MobileDevice/Provisioning Profiles",
                         "Library/Developer/Xcode/UserData/Provisioning Profiles"):
            destination = Path.home() / relative / (info["UUID"] + suffix)
            destination.parent.mkdir(parents=True, exist_ok=True)
            # Record ownership before writing, so cleanup also handles partial failure.
            config["profiles"].append(str(destination))
            write_private(config_path, json.dumps(config).encode())
            write_private(destination, profile)
    print(f"Installed {platform} signing credentials in the temporary build keychain")


def cleanup(directory):
    config_path = directory / "config.json"
    if config_path.exists():
        for value in json.loads(config_path.read_text()).get("profiles", []):
            Path(value).unlink(missing_ok=True)
    keychain_path = directory / "build.keychain-db"
    if keychain_path.exists():
        run(["security", "delete-keychain", str(keychain_path)])
    if directory.exists():
        shutil.rmtree(directory)
    print("Removed temporary Apple signing credentials")


def main():
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("This helper only runs on GitHub Actions")
    directory = Path(os.environ["RUNNER_TEMP"]) / "apple-release-signing"
    if sys.argv[1:] == ["validate"]:
        validate()
    elif sys.argv[1:] == ["cleanup"]:
        cleanup(directory)
    elif len(sys.argv) == 3 and sys.argv[1] == "install":
        install(directory, sys.argv[2])
    else:
        raise ValueError("Usage: apple_signing.py install ios|macos, or cleanup")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError) as error:
        print(f"Apple signing: {error}", file=sys.stderr)
        sys.exit(1)
