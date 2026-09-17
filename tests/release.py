#!/usr/bin/env python3
"""Exercise release packaging against real Git history and ZIP contents."""

import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / ".github/scripts/package-release.py"


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="twoku-release-test-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Release test")
        self.git("config", "user.email", "release@example.invalid")
        self.manifest = "title=Twoku\nmajor_version=0\nminor_version=0\nbuild_version=00000\n"
        files = {
            "manifest": self.manifest,
            "source/main.brs": "sub main()\nend sub\n",
            "components/qr/LICENSE.txt": "component license\n",
            "images/icon.png": "image fixture\n",
            "fonts/font.ttf": "font fixture\n",
            "README.md": "not part of the app\n",
        }
        for name, content in files.items():
            path = self.repo / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        self.commit = self.save_commit()
        (self.repo / "source/main.brs").write_text("newer code\n")
        self.save_commit()
        (self.repo / "source/main.brs").write_text("uncommitted code\n")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, text=True).strip()

    def save_commit(self):
        self.git("add", ".")
        self.git("commit", "-qm", "Fixture")
        return self.git("rev-parse", "HEAD")

    def package(self, commit, major="1", minor="2", build="3"):
        return subprocess.run(
            [sys.executable, str(SCRIPT), commit, major, minor, build, str(self.repo / "output")],
            cwd=self.repo, text=True, capture_output=True,
        )

    def test_requested_commit_and_version_are_in_installable_zip(self):
        for commit in [self.commit, self.commit[:8].upper()]:
            with self.subTest(commit=commit):
                result = self.package(commit)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"sha={self.commit}\n", result.stdout)
                self.assertIn("version=1.2.3\n", result.stdout)
                self.assertIn("tag=v1.2.3\n", result.stdout)
                archive = self.repo / "output/twoku.zip"
                with zipfile.ZipFile(archive) as package:
                    self.assertIsNone(package.testzip())
                    self.assertEqual(set(package.namelist()), {
                        "manifest", "source/", "source/main.brs", "components/",
                        "components/qr/", "components/qr/LICENSE.txt", "images/",
                        "images/icon.png", "fonts/", "fonts/font.ttf",
                    })
                    self.assertEqual(package.read("source/main.brs"), b"sub main()\nend sub\n")
                    self.assertEqual(package.read("manifest"), b"title=Twoku\nmajor_version=1\nminor_version=2\nbuild_version=00003\n")
                digest = hashlib.sha256(archive.read_bytes()).hexdigest()
                self.assertEqual((self.repo / "output/twoku.zip.sha256").read_text(), f"{digest}  twoku.zip\n")
        self.assertEqual((self.repo / "manifest").read_text(), self.manifest)
        self.assertEqual((self.repo / "source/main.brs").read_text(), "uncommitted code\n")

    def test_rejects_invalid_inputs_before_writing_an_archive(self):
        for commit in ["master", "HEAD", "abcdef", "0" * 40]:
            with self.subTest(commit=commit):
                self.assertNotEqual(self.package(commit).returncode, 0)
                self.assertFalse((self.repo / "output").exists())
        for field in range(3):
            for invalid in ["", "-1", "+1", "1.5", "1e2", "true", " 1", "1\ntag=bad", "$(touch injected)"]:
                with self.subTest(field=field, value=invalid):
                    numbers = ["1", "2", "3"]
                    numbers[field] = invalid
                    result = self.package(self.commit, *numbers)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("must be a non-negative integer", result.stderr)
                    self.assertFalse((self.repo / "output").exists())

    def test_workflow_build_number_is_repeatable_and_advances_without_wrapping(self):
        archives = []
        for build in ["42", "42", "43", "100000"]:
            with self.subTest(build=build):
                result = self.package(self.commit, "0", "9", build)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"version=0.9.{build}\n", result.stdout)
                self.assertIn(f"tag=v0.9.{build}\n", result.stdout)
                archive = self.repo / "output/twoku.zip"
                with zipfile.ZipFile(archive) as package:
                    self.assertEqual(package.read("manifest"), (
                        "title=Twoku\nmajor_version=0\nminor_version=9\n"
                        f"build_version={int(build):05d}\n"
                    ).encode())
                archives.append(archive.read_bytes())
        self.assertEqual(archives[0], archives[1])
        self.assertNotEqual(archives[1], archives[2])
        self.assertNotEqual(archives[2], archives[3])
        self.assertEqual((self.repo / "manifest").read_text(), self.manifest)

    def test_zero_and_leading_zero_inputs_produce_canonical_tags(self):
        cases = [
            (("0", "0", "0"), "0.0.0", "00000"),
            (("01", "02", "00003"), "1.2.3", "00003"),
        ]
        for inputs, version, build in cases:
            with self.subTest(inputs=inputs):
                result = self.package(self.commit, *inputs)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"version={version}\n", result.stdout)
                self.assertIn(f"tag=v{version}\n", result.stdout)
                with zipfile.ZipFile(self.repo / "output/twoku.zip") as package:
                    major, minor, _ = version.split(".")
                    self.assertEqual(package.read("manifest"), (
                        f"title=Twoku\nmajor_version={major}\nminor_version={minor}\nbuild_version={build}\n"
                    ).encode())

    def test_rejects_missing_or_duplicate_manifest_versions(self):
        for manifest in [self.manifest.replace("build_version=00000\n", ""), self.manifest + "major_version=2\n"]:
            with self.subTest(manifest=manifest):
                (self.repo / "manifest").write_text(manifest)
                commit = self.save_commit()
                self.assertNotEqual(self.package(commit).returncode, 0)
                self.assertFalse((self.repo / "output").exists())


if __name__ == "__main__":
    unittest.main()
