#!/usr/bin/env python3
"""Generate the versioned App Store marketing kit from current Flutter UI."""
import argparse
import datetime as dt
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / 'app-store/content.json'
DEVICES = [
    {'id': 'iphone_6_9', 'name': 'iPhone', 'width': 1320, 'height': 2868, 'scale': 3},
    {'id': 'ipad_13', 'name': 'iPad', 'width': 2064, 'height': 2752, 'scale': 2},
    {'id': 'mac', 'name': 'Mac', 'width': 2560, 'height': 1600, 'scale': 2},
]

def run(args, **kwargs):
    print('+ ' + ' '.join(str(x) for x in args[:3]), flush=True)
    return subprocess.run([str(x) for x in args], check=True, cwd=ROOT, **kwargs)

def release_version():
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', (ROOT / 'pubspec.yaml').read_text(), re.M)
    if not match:
        raise SystemExit('Expected version: major.minor.patch+build in pubspec.yaml')
    return match.groups()

def validate_content(content):
    for key, limit in [('name', 30), ('subtitle', 30), ('keywords', 100), ('promotional_text', 170), ('description', 4000), ('release_notes', 4000)]:
        value = content[key]
        if not isinstance(value, str) or not value.strip() or len(value) > limit:
            raise ValueError(f'{key} must contain 1–{limit} characters')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', content['repository']):
        raise ValueError('Invalid GitHub repository')
    if not re.fullmatch(r'[a-z]{2}-[A-Z]{2}', content['locale']):
        raise ValueError('Expected locale such as en-GB')
    scenes = content['scenes']
    if {s['id'] for s in scenes} != {'dashboard', 'licences', 'detail', 'share', 'products'} or len(scenes) != 5:
        raise ValueError('Exactly five supported scenes are required')
    for scene in scenes:
        if not 2 <= scene['seconds'] <= 8:
            raise ValueError('Scene duration must be between 2 and 8 seconds')
    duration = sum(s['seconds'] for s in scenes) - 0.4 * (len(scenes) - 1)
    if not 15 <= duration <= 30:
        raise ValueError('Marketing sequence must run for 15–30 seconds')


def metadata(folder, content, version, build):
    target = folder / 'metadata' / content['locale']
    target.mkdir(parents=True)
    for field in ['name', 'subtitle', 'description', 'keywords', 'promotional_text', 'release_notes', 'support_url', 'marketing_url', 'privacy_url']:
        (target / f'{field}.txt').write_text(content[field] + '\n')
    (folder / 'metadata/review-notes.txt').write_text(content['review_notes'] + '\n')
    (folder / 'metadata/copyright.txt').write_text(f'{dt.datetime.now(dt.timezone.utc).year} {content["publisher"]}\n')
    (folder / 'metadata/primary_category.txt').write_text('DEVELOPER_TOOLS\n')
    (folder / 'store-copy.md').write_text(f'# {content["name"]} {version} ({build})\n\n'
        + '\n\n'.join(f'## {field.replace("_", " ").title()}\n\n{content[field]}' for field in [
            'subtitle', 'promotional_text', 'description', 'keywords', 'release_notes', 'review_notes', 'privacy_url', 'support_url']) + '\n')


def encode_video(folder, orientation, scenes):
    width, height = (1080, 1920) if orientation == 'portrait' else (1920, 1080)
    frames = folder / 'video-frames' / orientation
    output = folder / 'videos' / f'keygen-client-{orientation}.mp4'
    output.parent.mkdir(exist_ok=True)
    args = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-filter_complex_threads', '1']
    for scene in scenes:
        args += ['-loop', '1', '-framerate', '30', '-t', str(scene['seconds']), '-i', str(frames / f'{scene["id"]}.png')]
    args += ['-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000']
    filters = [f'[{i}:v]scale={width}:{height},format=yuv420p,setsar=1,settb=AVTB,setpts=PTS-STARTPTS[v{i}]' for i in range(len(scenes))]
    previous = 'v0'
    elapsed = scenes[0]['seconds']
    for i in range(1, len(scenes)):
        label = f'x{i}'
        filters.append(f'[{previous}][v{i}]xfade=transition=fade:duration=0.4:offset={elapsed - 0.4:.2f}[{label}]')
        previous = label
        elapsed += scenes[i]['seconds'] - 0.4
    args += ['-filter_complex', ';'.join(filters), '-map', f'[{previous}]', '-map', f'{len(scenes)}:a',
        '-t', f'{elapsed:.2f}', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20', '-profile:v', 'high',
        '-pix_fmt', 'yuv420p', '-r', '30', '-threads', '2', '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', str(output)]
    run(args)
    shutil.copyfile(frames / 'dashboard.png', folder / 'videos' / f'keygen-client-{orientation}-poster.png')


def gallery(folder, content, version, build):
    esc = html.escape
    cards = []
    for device in DEVICES:
        cards.append(f'<h2>{device["name"]}</h2><div class="grid">')
        for appearance in ['dark', 'light']:
            for index, scene in enumerate(content['scenes'], 1):
                path = f'screenshots/{content["locale"]}/{device["id"]}/{index:02d}-{scene["id"]}-{appearance}.png'
                cards.append(f'<a class="card" href="{path}"><img loading="lazy" src="{path}" alt="{esc(scene["title"])} — {appearance}"><span>{esc(scene["title"])} <small>{appearance}</small></span></a>')
        cards.append('</div>')
    (folder / 'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Keygen Client — Release marketing kit</title><style>
*{box-sizing:border-box}body{margin:0;background:#0b141e;color:#eaf1f7;font:16px -apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;line-height:1.5}main{max-width:1320px;margin:auto;padding:64px 28px}header{max-width:820px;margin-bottom:56px}.brand{display:flex;align-items:center;gap:16px;color:#7ef0cf;font-weight:650}.brand img{width:56px;border-radius:13px}h1{font-size:clamp(40px,6vw,76px);line-height:1.05;letter-spacing:-2px;margin:32px 0 20px}h2{margin-top:64px;font-size:28px}p,small{color:#a9c0cd}a{color:#7ef0cf}nav{display:flex;flex-wrap:wrap;gap:20px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:20px}.card{overflow:hidden;text-decoration:none;border:1px solid #294153;border-radius:18px;background:#101e2b}.card img{display:block;width:100%;height:320px;object-fit:contain;background:#0a131c}.card span{display:block;padding:16px;color:#eaf1f7}.card small{display:block}.videos{display:grid;grid-template-columns:1fr 1fr;gap:24px}video{width:100%;max-height:580px;background:#050c13;border-radius:16px;border:1px solid #294153}footer{margin-top:64px;border-top:1px solid #294153;padding-top:24px}@media(max-width:700px){.videos{grid-template-columns:1fr}}
</style><main><header><div class="brand"><img src="images/app-icon.png" alt="">AXYM LABS · RELEASE KIT</div>'''
        + f'<h1>{esc(content["tagline"])}</h1><p>{esc(content["name"])} {version} · build {build}. Screens and marketing cuts generated from the current app with a fictional sample workspace.</p>'
        + '<nav><a href="store-copy.md">Store copy</a><a href="manifest.json">Asset manifest</a><a href="SHA256SUMS.txt">Checksums</a></nav></header>'
        + '<h2>The app, in motion.</h2><div class="videos">'
        + ''.join(f'<video controls preload="metadata" poster="videos/keygen-client-{o}-poster.png"><source src="videos/keygen-client-{o}.mp4" type="video/mp4"></video>' for o in ['portrait', 'landscape'])
        + '</div><p>These are promotional motion cuts made from rendered UI. They are not device-recorded App Store Preview submissions.</p>'
        + ''.join(cards) + '<footer>Independent client; not affiliated with or endorsed by Keygen. All names, licence keys and resource records shown are fictional sample data. Privacy/support website content must be published before an App Store submission.</footer></main>')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', help='Require a release tag matching pubspec.yaml')
    args = parser.parse_args()
    version, build = release_version()
    edition = f'{version}+{build}'
    if args.tag and args.tag not in [f'v{version}', f'v{edition}']:
        raise SystemExit(f'Release tag {args.tag!r} does not match pubspec.yaml {edition}')
    content = json.loads(CONTENT.read_text())
    validate_content(content)
    for executable in ['flutter', 'swift', 'ffmpeg', 'ffprobe']:
        if not shutil.which(executable):
            raise SystemExit(f'Required tool missing: {executable}')
    flutter_root = Path(shutil.which('flutter')).resolve().parent.parent
    generated = ROOT / 'app-store/generated'
    generated.mkdir(exist_ok=True)
    destination = generated / edition
    archive = generated / f'keygen-client-app-store-{edition}.zip'
    with tempfile.TemporaryDirectory(prefix='.render-', dir=generated) as temp:
        folder = Path(temp) / edition
        folder.mkdir()
        plan = {'flutter_root': str(flutter_root), 'output': str(folder / 'raw'), 'devices': DEVICES, 'version': version, 'build': build}
        capture_plan = Path(temp) / 'capture.json'
        capture_plan.write_text(json.dumps(plan))
        env = dict(os.environ, APP_STORE_CAPTURE_PLAN=str(capture_plan))
        run(['flutter', 'test', 'test/app_store_capture_test.dart'], env=env)
        metadata(folder, content, version, build)
        (folder / 'images').mkdir()
        shutil.copyfile(ROOT / 'assets/brand/keygen-mark.png', folder / 'images/app-icon.png')
        jobs = []
        for device in DEVICES:
            for appearance in ['dark', 'light']:
                for index, scene in enumerate(content['scenes'], 1):
                    jobs.append({**scene, 'mode': 'screenshot', 'platform': device['name'], 'width': device['width'], 'height': device['height'],
                        'source': str(folder / 'raw' / device['id'] / appearance / f'{scene["id"]}.png'),
                        'output': str(folder / 'screenshots' / content['locale'] / device['id'] / f'{index:02d}-{scene["id"]}-{appearance}.png')})
        for orientation, device_id, width, height in [('portrait', 'iphone_6_9', 1080, 1920), ('landscape', 'mac', 1920, 1080)]:
            for scene in content['scenes']:
                jobs.append({**scene, 'mode': 'video', 'platform': 'iPhone · iPad · Mac', 'width': width, 'height': height,
                    'source': str(folder / 'raw' / device_id / 'dark' / f'{scene["id"]}.png'),
                    'output': str(folder / 'video-frames' / orientation / f'{scene["id"]}.png')})
        render_plan = Path(temp) / 'render.json'
        render_plan.write_text(json.dumps({'name': content['name'], 'edition': f'{version} ({build})',
            'mark': str(ROOT / 'assets/brand/keygen-mark.png'), 'jobs': jobs}))
        run(['swift', '-module-cache-path', str(generated / '.swift-cache'), 'tool/app_store/render.swift', str(render_plan)])
        for orientation in ['portrait', 'landscape']:
            encode_video(folder, orientation, content['scenes'])
        shutil.copyfile(folder / 'video-frames/landscape/dashboard.png', folder / 'images/release-hero.png')
        gallery(folder, content, version, build)
        try:
            commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, stderr=subprocess.DEVNULL, text=True).strip()
            dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip())
        except subprocess.CalledProcessError:
            commit = None
            dirty = True
        (folder / 'README.md').write_text(f'# {content["name"]} {version} ({build}) — marketing kit\n\nOpen index.html for the gallery.\n\n'
            'screenshots/: branded PNGs at Apple listing dimensions; raw/: unframed UI renders; videos/: two promotional MP4 cuts and poster frames; metadata/: localized store text; images/: app icon and release hero.\n\n'
            'Generated from fictional in-memory sample resources. No live server or account credentials are used. Marketing videos are rendered promotional cuts, not device-recorded App Store Previews. This bundle is published to GitHub Releases only.\n\n'
            'Publish and verify the linked privacy/support sections on axym.dev before copying this metadata into App Store Connect.\n')
        assets = []
        for path in sorted(folder.rglob('*')):
            if path.is_file():
                assets.append({'path': path.relative_to(folder).as_posix(), 'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        manifest = {'generator': 'keygen-app-store', 'name': content['name'], 'version': version, 'build': build,
            'bundle_id': content['bundle_id'], 'repository': content['repository'], 'source_commit': commit,
            'source_dirty': dirty, 'generated_at': dt.datetime.now(dt.timezone.utc).isoformat(), 'locale': content['locale'],
            'sample_data': True, 'video_type': 'rendered_marketing_cut', 'assets': assets, 'devices': DEVICES}
        (folder / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        (folder / 'SHA256SUMS.txt').write_text(''.join(f'{item["sha256"]}  {item["path"]}\n' for item in assets)
            + hashlib.sha256((folder / 'manifest.json').read_bytes()).hexdigest() + '  manifest.json\n')
        run(['python3', 'tool/app_store/verify.py', str(folder)])
        if destination.exists():
            previous = destination / 'manifest.json'
            if not previous.exists() or json.loads(previous.read_text()).get('generator') != 'keygen-app-store':
                raise SystemExit(f'Refusing to replace an unrecognized output folder: {destination}')
            shutil.rmtree(destination)
        shutil.move(str(folder), destination)
        temporary_zip = Path(temp) / archive.name
        with zipfile.ZipFile(temporary_zip, 'w', zipfile.ZIP_DEFLATED) as output:
            for path in sorted(destination.rglob('*')):
                if path.is_file():
                    output.write(path, f'{edition}/{path.relative_to(destination).as_posix()}')
        shutil.move(str(temporary_zip), archive)
    (generated / f'{archive.name}.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + f'  {archive.name}\n')
    print(f'Generated {destination}\nBundle: {archive}')

if __name__ == '__main__':
    main()
