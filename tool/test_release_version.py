#!/usr/bin/env python3
"""Exercise version bumps, tag validation and built bundle verification."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

class ReleaseVersionTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / 'tool').mkdir()
        self.script = self.root / 'tool/release_version.py'
        shutil.copyfile(Path(__file__).with_name('release_version.py'), self.script)
        self.pubspec = self.root / 'pubspec.yaml'
        self.pubspec.write_text('name: example\nversion: 1.2.3+4\n\nenvironment:\n  sdk: ^3.13.0\n')
    def tearDown(self): self.tmp.cleanup()
    def run_version(self, *args):
        return subprocess.run([sys.executable, str(self.script), *args], text=True, capture_output=True)
    def test_tag_matches_marketing_version_only(self):
        self.assertEqual(self.run_version('check', 'v1.2.3').returncode, 0)
        self.assertNotEqual(self.run_version('check', 'v1.2.3+4').returncode, 0)
        self.assertNotEqual(self.run_version('check', 'v1.2.4').returncode, 0)
    def test_bump_preserves_pubspec_structure(self):
        self.assertEqual(self.run_version('bump', 'patch').returncode, 0)
        self.assertIn('version: 1.2.4+5\n\nenvironment:\n', self.pubspec.read_text())
        self.assertEqual(self.run_version('bump', 'build').stdout.strip(), '1.2.4 6')
    def test_marketing_version_bumps_keep_build_increasing(self):
        self.assertEqual(self.run_version('bump', 'minor').stdout.strip(), '1.3.0 5')
        self.assertEqual(self.run_version('bump', 'major').stdout.strip(), '2.0.0 6')
    def test_bundle_must_match_both_values(self):
        bundle = self.root / 'Example.app'
        bundle.mkdir()
        (bundle / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '1.2.3', 'CFBundleVersion': '4'}))
        self.assertEqual(self.run_version('check', '--bundle', str(bundle)).returncode, 0)
        (bundle / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': '1.2.3', 'CFBundleVersion': '5'}))
        self.assertNotEqual(self.run_version('check', '--bundle', str(bundle)).returncode, 0)
    def test_requires_positive_build_number(self):
        self.pubspec.write_text('version: 1.2.3\n')
        self.assertNotEqual(self.run_version('check').returncode, 0)

if __name__ == '__main__': unittest.main()
