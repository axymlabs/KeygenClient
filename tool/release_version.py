#!/usr/bin/env python3
"""Keep pubspec, Git tags and assembled Apple bundles on one version."""
import argparse
from pathlib import Path
import re
import plistlib

ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / 'pubspec.yaml'
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('command', choices=['check', 'bump'])
p.add_argument('value', nargs='?')
p.add_argument('--bundle', type=Path)
a = p.parse_args()
s = PUBSPEC.read_text()
m = re.search(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+([1-9]\d*)[ \t]*$', s, re.M)
if not m:
    p.error('pubspec.yaml must have version: major.minor.patch+positive_build')
major, minor, patch, build = map(int, m.groups())
if a.command == 'bump':
    if a.value == 'major': major, minor, patch, build = major + 1, 0, 0, 1
    elif a.value == 'minor': minor, patch, build = minor + 1, 0, 1
    elif a.value == 'patch': patch, build = patch + 1, 1
    elif a.value == 'build': build += 1
    else: p.error('bump requires major, minor, patch or build')
    s = s[:m.start()] + f'version: {major}.{minor}.{patch}+{build}' + s[m.end():]
    PUBSPEC.write_text(s)
name = f'{major}.{minor}.{patch}'
if a.command == 'check' and a.value and a.value != 'v' + name:
    p.error(f'tag {a.value} does not match pubspec version v{name}')
if a.bundle:
    f = a.bundle / 'Info.plist'
    if not f.exists(): f = a.bundle / 'Contents/Info.plist'
    info = plistlib.loads(f.read_bytes())
    if (info.get('CFBundleShortVersionString'), info.get('CFBundleVersion')) != (name, str(build)):
        p.error('Apple bundle version or build differs from pubspec.yaml')
print(name, build)
