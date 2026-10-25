#!/usr/bin/env python3
"""Validate shared release metadata and optionally an assembled Apple bundle."""
import argparse
import json
import plistlib
import re
import struct
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--bundle', type=Path)
parser.add_argument('--strict', action='store_true', help='Require publisher identity and public release URLs')
parser.add_argument('--config', type=Path, help='JSON passed to Flutter --dart-define-from-file')
args = parser.parse_args()
errors = []

def check(condition, message):
    if not condition:
        errors.append(message)

version = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', (ROOT / 'pubspec.yaml').read_text(), re.M)
if not version:
    raise SystemExit('pubspec.yaml must specify version: major.minor.patch+build')
name, build = version.groups()
ios_ids = set(re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = ([\w.]+);',
                        (ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text()))
mac_id = re.search(r'^PRODUCT_BUNDLE_IDENTIFIER = ([\w.]+)$',
                   (ROOT / 'macos/Runner/Configs/AppInfo.xcconfig').read_text(), re.M).group(1)
check(ios_ids == {mac_id, mac_id + '.RunnerTests'}, 'Apple bundle IDs must agree across app and test targets')
mac_targets = set(re.findall(r'MACOSX_DEPLOYMENT_TARGET = ([\d.]+);',
                            (ROOT / 'macos/Runner.xcodeproj/project.pbxproj').read_text()))
check(len(mac_targets) == 1, 'Mac build configurations must use the same deployment target')
for platform in ['ios', 'macos']:
    runner = ROOT / platform / 'Runner'
    export_options = plistlib.loads((ROOT / platform / 'ExportOptions.plist').read_bytes())
    check(export_options.get('manageAppVersionAndBuildNumber') is False,
          f'{platform}: export must preserve the configured version and build')
    info = plistlib.loads((runner / 'Info.plist').read_bytes())
    check(info['CFBundleShortVersionString'] == '$(FLUTTER_BUILD_NAME)', f'{platform}: version must come from Flutter')
    check(info['CFBundleVersion'] == '$(FLUTTER_BUILD_NUMBER)', f'{platform}: build must come from Flutter')
    manifest = runner / 'PrivacyInfo.xcprivacy'
    plistlib.loads(manifest.read_bytes())
    project = (ROOT / platform / 'Runner.xcodeproj/project.pbxproj').read_text()
    if sys.platform == 'darwin':
        result = subprocess.run(['plutil', '-lint', str(ROOT / platform / 'Runner.xcodeproj/project.pbxproj')], capture_output=True)
        check(result.returncode == 0, f'{platform}: invalid Xcode project syntax')
    check('PrivacyInfo.xcprivacy in Resources' in project, f'{platform}: privacy manifest must be bundled')
    check(not re.search(r'(?:MARKETING_VERSION|CURRENT_PROJECT_VERSION) = [0-9]', project), f'{platform}: hardcoded Xcode version')
    catalog = runner / 'Assets.xcassets/AppIcon.appiconset'
    for entry in json.loads((catalog / 'Contents.json').read_text())['images']:
        if 'filename' not in entry:
            continue
        data = (catalog / entry['filename']).read_bytes()
        w, h, depth, color = struct.unpack('>IIBB', data[16:26])
        expected = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
        check(w == h == expected, f'{platform}: incorrect icon dimensions: {entry["filename"]}')
        if platform == 'ios':
            check(color in (0, 2), f'iOS icon must have no alpha channel: {entry["filename"]}')
    if args.strict:
        identity = project + ((runner / 'Configs/AppInfo.xcconfig').read_text() if platform == 'macos' else '')
        check('com.example.' not in identity, f'{platform}: replace com.example bundle IDs with registered IDs')
        check('DEVELOPMENT_TEAM = ' in identity, f'{platform}: configure an Apple Developer team')

if args.strict:
    config = json.loads(args.config.read_text()) if args.config else {}
    for key in ['PRIVACY_POLICY_URL', 'SUPPORT_URL']:
        uri = urlparse(config.get(key, ''))
        check(uri.scheme == 'https' and bool(uri.netloc) and not uri.netloc.endswith(('example.com', 'example.org')),
              f'{key}: provide a public HTTPS URL in --config')

if args.bundle:
    bundle = args.bundle
    info_path = bundle / 'Info.plist'
    if not info_path.exists():
        info_path = bundle / 'Contents/Info.plist'
    info = plistlib.loads(info_path.read_bytes())
    check(info.get('CFBundleShortVersionString') == name, 'Built app marketing version differs from pubspec.yaml')
    check(info.get('CFBundleVersion') == build, 'Built app build number differs from pubspec.yaml')
    check(info.get('CFBundleDisplayName', info.get('CFBundleName')) == 'Keygen Client', 'Built app display name is inconsistent')
    manifest_path = bundle / ('Contents/Resources/PrivacyInfo.xcprivacy' if (bundle / 'Contents').exists() else 'PrivacyInfo.xcprivacy')
    check(manifest_path.exists(), 'Built app is missing its privacy manifest')
    if (bundle / 'Contents').exists():
        check(info.get('LSMinimumSystemVersion') in mac_targets,
              'Built Mac minimum OS differs from the configured deployment target')
    if args.strict:
        check(not info.get('CFBundleIdentifier', '').startswith('com.example.'), 'Built app uses a placeholder bundle ID')
        check(info.get('CFBundleIdentifier') == mac_id, 'Built app bundle ID differs from the configured identity')

if errors:
    raise SystemExit('\n'.join(f'ERROR: {error}' for error in errors))
print(f'Release metadata verified: Keygen Client {name} ({build})' + ('; bundle checked' if args.bundle else ''))
if not args.strict:
    print('This checks local metadata only. Run --strict --config <release.json> before distribution.')
