#!/usr/bin/env python3
"""Validate marketing output, image geometry, video encoding and file integrity."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import struct
import subprocess


def png_size(path):
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or len(data) < 29:
        raise ValueError(f'Invalid PNG: {path}')
    width, height = struct.unpack('>II', data[16:24])
    return width, height, data[25]


def verify(folder):
    manifest = json.loads((folder / 'manifest.json').read_text())
    if manifest.get('generator') != 'keygen-app-store':
        raise ValueError('Unknown generator')
    assets = manifest['assets']
    seen = set()
    for asset in assets:
        relative = PurePosixPath(asset['path'])
        if relative.is_absolute() or '..' in relative.parts or relative.as_posix() in seen:
            raise ValueError('Invalid or duplicate manifest path')
        seen.add(relative.as_posix())
        path = folder / relative
        if path.is_symlink() or not path.is_file():
            raise ValueError(f'Missing/non-regular asset: {relative}')
        if path.stat().st_size != asset['bytes'] or hashlib.sha256(path.read_bytes()).hexdigest() != asset['sha256']:
            raise ValueError(f'Asset integrity mismatch: {relative}')
    actual = {p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()}
    if actual != seen | {'manifest.json', 'SHA256SUMS.txt'}:
        raise ValueError('Output contains files missing from the manifest')
    for line in (folder / 'SHA256SUMS.txt').read_text().splitlines():
        digest, path = line.split('  ', 1)
        if path not in actual or hashlib.sha256((folder / path).read_bytes()).hexdigest() != digest:
            raise ValueError('Checksum mismatch')
    for device in manifest['devices']:
        files = sorted((folder / 'screenshots' / manifest['locale'] / device['id']).glob('*.png'))
        if len(files) != 10:
            raise ValueError(f'Expected 5 scenes × 2 appearances for {device["id"]}')
        for file in files:
            w, h, color_type = png_size(file)
            if (w, h) != (device['width'], device['height']) or color_type != 2:
                raise ValueError(f'Wrong dimensions or non-RGB listing screenshot: {file.name}')
    for orientation, size in [('portrait', (1080, 1920)), ('landscape', (1920, 1080))]:
        path = folder / f'videos/keygen-client-{orientation}.mp4'
        probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)], text=True))
        video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
        audio = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
        if (video['width'], video['height']) != size or video['codec_name'] != 'h264' or video['pix_fmt'] != 'yuv420p':
            raise ValueError(f'Unexpected video encoding for {orientation}')
        if video['r_frame_rate'] != '30/1' or audio['codec_name'] != 'aac' or not 15 <= float(probe['format']['duration']) <= 30:
            raise ValueError(f'Unexpected duration, frame rate or audio for {orientation}')
    print(f'Verified {len(assets)} assets for {manifest["version"]} ({manifest["build"]})')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    verify(parser.parse_args().folder.resolve())
