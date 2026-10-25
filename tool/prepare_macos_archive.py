#!/usr/bin/env python3
"""Normalize unsigned Flutter framework signing identifiers before Xcode export.

Xcode's cloud distribution signer can preserve linker-generated requirements such
as `identifier App` while signing with the framework's CFBundleIdentifier. That
mismatch makes the final app fail nested-code validation. Ad-hoc signing with the
actual bundle identifier gives the exporter a consistent designated requirement.
"""
import argparse
import plistlib
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
args = parser.parse_args()
apps = list((args.archive / 'Products/Applications').glob('*.app'))
if len(apps) != 1:
    raise SystemExit('Expected one application in the archive')
for framework in sorted((apps[0] / 'Contents/Frameworks').glob('*.framework')):
    info = framework / 'Resources/Info.plist'
    if not info.exists():
        info = framework / 'Info.plist'
    identifier = plistlib.loads(info.read_bytes())['CFBundleIdentifier']
    subprocess.run(['codesign', '--force', '--sign', '-', '--identifier', identifier,
                    '--options', 'runtime', '--timestamp=none', str(framework)], check=True)
    subprocess.run(['codesign', '--verify', '--strict', str(framework)], check=True)
    print(f'Prepared {framework.name}: {identifier}')

# The unsigned app's linker identifier can also be its executable name rather
# than CFBundleIdentifier. Give the exporter the real identity and release
# entitlements, and preserve hardened runtime on the final distribution build.
app = apps[0]
identifier = plistlib.loads((app / 'Contents/Info.plist').read_bytes())['CFBundleIdentifier']
entitlements = Path(__file__).resolve().parent.parent / 'macos/Runner/Release.entitlements'
subprocess.run(['codesign', '--force', '--sign', '-', '--identifier', identifier,
                '--options', 'runtime', '--timestamp=none', '--entitlements', str(entitlements),
                str(app)], check=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
print(f'Prepared application: {identifier}')
