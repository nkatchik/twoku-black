# Fonts

Interface labels use Roku's `font:SystemFontFile` and `font:BoldSystemFontFile`.
Titles, display names, categories, descriptions, and chat use the single bundled
`TwokuUnicode-Regular.ttf`. Roxton's native fonts lack CJK, Korean, and emoji;
switching user content to native fonts would leave missing-character boxes.

Twoku Unicode combines regular Noto Sans, Android's Droid Sans Fallback, Noto
Sans Arabic/Thai/Hebrew/Devanagari, and monochrome Noto Emoji. It includes about
40,000 codepoints, not all of Unicode. Complex-script layout still depends on
Roku's text renderer. This font is larger than the former decorative fonts
because it contains substantially more glyphs. No fonts are downloaded or
merged at runtime.

The derived font is distributed under the SIL Open Font License 1.1. Droid Sans
portions retain their Apache 2.0 license. Original notices are in `licenses/`.
Droid Sans font data: Copyright 2006 Google Corporation.
Modifications: instantiate regular weight, normalize units, remove hinting and
vertical tables, merge character coverage, rename the family, and normalize
horizontal line spacing for the existing UI. Upstream URLs, immutable revisions,
and checksums are recorded in [font-sources.json](../tools/font-sources.json).

To regenerate (only needed when changing the font):

```sh
python3 -m venv /tmp/twoku-font-env
/tmp/twoku-font-env/bin/pip install fonttools==4.65.0
/tmp/twoku-font-env/bin/python tools/build-font.py
/tmp/twoku-font-env/bin/python tests/fonts.py
```

Inputs are cached by checksum in the system temporary directory. A repeat build
uses the cache and produces the same TTF bytes. Ordinary builds use the committed
font and need no font tooling.
