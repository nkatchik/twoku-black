#!/usr/bin/env python3
"""Rebuild the bundled Unicode font with fonttools==4.65.0 (offline cache optional)."""

import argparse
import base64
import hashlib
import json
from pathlib import Path
import tempfile
from urllib.request import urlopen

from fontTools import version
from fontTools.merge import Merger
from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[1]


def fetch(source, cache):
    path = cache / source["sha256"]
    if not path.exists():
        with urlopen(source["url"], timeout=60) as response:
            data = response.read()
        if source.get("encoding") == "base64":
            data = base64.b64decode(data)
        if hashlib.sha256(data).hexdigest() != source["sha256"]:
            raise ValueError(f"Unexpected source checksum: {source['url']}")
        path.write_bytes(data)
    if hashlib.sha256(path.read_bytes()).hexdigest() != source["sha256"]:
        raise ValueError(f"Corrupt cached source: {path}")
    return path


def build(cache, output):
    if version != "4.65.0":
        raise ValueError("Use fonttools==4.65.0 for reproducible font generation")
    sources = json.loads((ROOT / "tools/font-sources.json").read_text())
    cache.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="twoku-font-") as temp:
        parts = []
        for source in sources:
            font = TTFont(fetch(source["font"], cache), recalcTimestamp=False)
            license_data = fetch(source["license"], cache).read_bytes()
            license_path = ROOT / "fonts/licenses" / (source["family"] + ".txt")
            if license_path.read_bytes() != license_data:
                raise ValueError(f"Bundled license differs from upstream: {license_path}")
            if "fvar" in font:
                axes = {axis.axisTag: 400 if axis.axisTag == "wght" else axis.defaultValue
                        for axis in font["fvar"].axes}
                instantiateVariableFont(font, axes, inplace=True)
            # Roku uses horizontal, static TrueType fonts. Keep shaping tables;
            # remove vertical-only metrics and bytecode from mixed UPM sources.
            for tag in ("vhea", "vmtx", "VORG"):
                if tag in font:
                    del font[tag]
            if font["head"].unitsPerEm != 2048:
                scale_upem(font, 2048)
            options = Options()
            options.hinting = False
            options.layout_features = ["*"]
            subset = Subsetter(options=options)
            subset.populate(unicodes=font.getBestCmap())
            subset.subset(font)
            path = Path(temp) / (source["family"] + ".ttf")
            font.save(path)
            parts.append(str(path))
        merged = Merger().merge(parts)

    # Merging sums the extreme metrics of unrelated scripts. Preserve the
    # existing app's 1.21em line spacing; retain full glyph extents in usWin*.
    merged["hhea"].ascent, merged["hhea"].descent, merged["hhea"].lineGap = 1984, -494, 0
    os2 = merged["OS/2"]
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = 1984, -494, 0
    names = {
        0: "Derived from Noto and Droid Sans. See bundled fonts/licenses notices.",
        1: "Twoku Unicode", 2: "Regular", 3: "Twoku Unicode 1.0",
        4: "Twoku Unicode Regular", 5: "Version 1.0", 6: "TwokuUnicode-Regular",
        13: "SIL Open Font License 1.1; Droid Sans portions under Apache License 2.0. See fonts/licenses.",
        14: "https://openfontlicense.org/", 16: "Twoku Unicode", 17: "Regular",
    }
    merged["name"].names = []
    for identifier, value in names.items():
        merged["name"].setName(value, identifier, 3, 1, 0x409)
    merged["head"].created = merged["head"].modified = 3872448000  # 2026-09-17 UTC
    merged.recalcTimestamp = False
    merged.save(output)
    print(f"{output}: {len(merged.getBestCmap())} codepoints, {output.stat().st_size} bytes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=Path(tempfile.gettempdir()) / "twoku-font-sources")
    parser.add_argument("--output", type=Path, default=ROOT / "fonts/TwokuUnicode-Regular.ttf")
    args = parser.parse_args()
    build(args.cache, args.output)
