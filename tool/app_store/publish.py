#!/usr/bin/env python3
"""Attach a validated marketing kit to an existing GitHub Release."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile
from generate import ROOT, release_version, validate_content
from verify import verify

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--tag', required=True)
args = parser.parse_args()
version, build = release_version()
if args.tag not in [f'v{version}', f'v{version}+{build}']:
    raise SystemExit('Release tag does not match pubspec.yaml')
content = json.loads((ROOT / 'app-store/content.json').read_text())
validate_content(content)
folder = ROOT / f'app-store/generated/{version}+{build}'
verify(folder)
manifest = json.loads((folder / 'manifest.json').read_text())
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
tag_commit = subprocess.check_output(['git', 'rev-list', '-n', '1', args.tag], cwd=ROOT, text=True).strip()
dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip())
if manifest.get('source_dirty', True) or dirty or manifest['source_commit'] != head or head != tag_commit:
    raise SystemExit('Assets, working source and release tag must refer to the same commit. Regenerate from the tag.')
archive = folder.parent / f'keygen-client-app-store-{version}+{build}.zip'
checksum = Path(str(archive) + '.sha256')
expected = checksum.read_text().split()[0]
if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
    raise SystemExit('Release ZIP checksum mismatch')
with zipfile.ZipFile(archive) as zipped:
    prefix = f'{version}+{build}/'
    expected_files = {prefix + p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()}
    if set(zipped.namelist()) != expected_files or len(zipped.namelist()) != len(expected_files):
        raise SystemExit('ZIP contents differ from the validated marketing kit')
    for path in expected_files:
        if hashlib.sha256(zipped.read(path)).digest() != hashlib.sha256((folder / path[len(prefix):]).read_bytes()).digest():
            raise SystemExit(f'ZIP asset differs from validated output: {path}')
repo = content['repository']
subprocess.run(['gh', 'release', 'view', args.tag, '--repo', repo], check=True)
# Upload only generated, validated assets; no source credentials or app binaries.
assets = [archive, checksum, folder / 'manifest.json', folder / 'store-copy.md',
          folder / 'images/release-hero.png', *sorted((folder / 'videos').glob('*'))]
subprocess.run(['gh', 'release', 'upload', args.tag, '--repo', repo, '--clobber', *map(str, assets)], check=True)
print(f'Published marketing assets: https://github.com/{repo}/releases/tag/{args.tag}')
