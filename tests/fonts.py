#!/usr/bin/env python3
"""Check the shipped font's actual coverage and the app's font references."""

from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]


class FontTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.font = TTFont(ROOT / "fonts/TwokuUnicode-Regular.ttf")

    @classmethod
    def tearDownClass(cls):
        cls.font.close()

    def test_title_and_chat_characters_have_real_outlines(self):
        cmap = self.font.getBestCmap()
        examples = [
            "café Español français Tiếng Việt Ελληνικά Привет Україна",
            "日本語 中文 한국어 ไทย العربية עברית हिन्दी",
            "♥ ★ 😀 🎮 🔴 🔥 😂 💜 👍 🥰 🚀",
        ]
        for text in examples:
            for character in text.replace(" ", ""):
                with self.subTest(character=character):
                    glyph_name = cmap.get(ord(character))
                    self.assertIsNotNone(glyph_name)
                    self.assertNotEqual(glyph_name, ".notdef")
                    glyph = self.font["glyf"][glyph_name]
                    self.assertTrue(glyph.isComposite() or glyph.numberOfContours > 0)

    def test_font_is_static_with_shaping_and_matching_line_spacing(self):
        self.assertNotIn("fvar", self.font)
        self.assertIn("GSUB", self.font)
        self.assertIn("GPOS", self.font)
        metrics = self.font["hhea"]
        self.assertLessEqual((metrics.ascent - metrics.descent + metrics.lineGap) /
                             self.font["head"].unitsPerEm, 1.22)

    def test_font_references_resolve(self):
        referenced = set()
        for path in (ROOT / "components").rglob("*"):
            if path.suffix not in (".xml", ".brs"):
                continue
            source = path.read_text()
            if path.suffix == ".xml":
                ET.fromstring(source)
            for name in re.findall(r"pkg:/fonts/([^\"\s]+)", source):
                referenced.add(name)
                self.assertTrue((ROOT / "fonts" / name).is_file(), (path, name))
        self.assertEqual(referenced, {path.name for path in (ROOT / "fonts").glob("*.ttf")})


if __name__ == "__main__":
    unittest.main()
