#!/usr/bin/env python3
"""Credential files must be private before secrets are written."""
from pathlib import Path
import os
import stat
import tempfile
import unittest
import apple_signing

class PrivateCredentialFileTest(unittest.TestCase):
    def test_create_is_private_even_with_permissive_umask(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / 'key'
            previous = os.umask(0)
            try:
                apple_signing.write_private(destination, b'test-only value')
            finally:
                os.umask(previous)
            self.assertEqual(stat.S_IMODE(destination.stat().st_mode), 0o600)
    def test_existing_file_is_restricted_before_replacement(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / 'config'
            destination.write_bytes(b'old public placeholder')
            destination.chmod(0o644)
            apple_signing.write_private(destination, b'test-only replacement')
            self.assertEqual(stat.S_IMODE(destination.stat().st_mode), 0o600)
    def test_refuses_symlink_targets(self):
        with tempfile.TemporaryDirectory() as directory:
            original = Path(directory) / 'original'
            original.write_bytes(b'unchanged')
            link = Path(directory) / 'link'
            link.symlink_to(original)
            with self.assertRaises(OSError):
                apple_signing.write_private(link, b'test-only value')
            self.assertEqual(original.read_bytes(), b'unchanged')

if __name__ == '__main__': unittest.main()
