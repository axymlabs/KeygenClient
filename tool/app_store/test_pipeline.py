"""Regression checks for metadata constraints and fail-before-publishing behavior."""
import copy
import json
import subprocess
import sys
import unittest
from generate import CONTENT, ROOT, validate_content

class ReleasePipelineTests(unittest.TestCase):
    def setUp(self):
        self.content = json.loads(CONTENT.read_text())

    def test_store_character_limits_are_enforced(self):
        for field, limit in [('name', 30), ('subtitle', 30), ('keywords', 100), ('promotional_text', 170), ('description', 4000)]:
            with self.subTest(field=field):
                invalid = copy.deepcopy(self.content)
                invalid[field] = 'x' * (limit + 1)
                with self.assertRaises(ValueError):
                    validate_content(invalid)

    def test_unexpected_scenes_fail_before_rendering(self):
        self.content['scenes'][0]['id'] = '../../private'
        with self.assertRaises(ValueError):
            validate_content(self.content)

    def test_short_marketing_sequence_is_rejected(self):
        for scene in self.content['scenes']:
            scene['seconds'] = 2
        with self.assertRaises(ValueError):
            validate_content(self.content)

    def test_generation_and_upload_reject_wrong_release_tag(self):
        for entry in ['generate.py', 'publish.py']:
            with self.subTest(entry=entry):
                result = subprocess.run([sys.executable, str(ROOT / 'tool/app_store' / entry), '--tag', 'v999.999.999'], cwd=ROOT, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(b'pubspec.yaml', result.stdout + result.stderr)

if __name__ == '__main__':
    unittest.main()
