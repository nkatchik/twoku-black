#!/usr/bin/env python3
"""Build a Roku sideload ZIP from a commit without changing the checkout."""

import argparse
import hashlib
import io
from pathlib import Path
import re
import subprocess
import zipfile


def package_release(commit, version, output):
    if not re.fullmatch(r"[0-9a-fA-F]{7,40}", commit):
        raise ValueError("Commit must be a full hash or at least 7 hexadecimal characters.")
    match = re.fullmatch(r"v?((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))", version)
    if not match:
        raise ValueError("Version must be MAJOR.MINOR.BUILD, optionally prefixed with v.")
    version = match[1]
    sha = subprocess.check_output(
        ["git", "rev-parse", "--verify", "--end-of-options", f"{commit.lower()}^{{commit}}"],
        text=True,
    ).strip()
    if not sha.startswith(commit.lower()):
        raise ValueError("Input resolved to a named ref instead of the requested commit hash.")

    source = subprocess.check_output([
        "git", "archive", "--format=zip", sha,
        "manifest", "source", "components", "images", "fonts",
    ])
    with zipfile.ZipFile(io.BytesIO(source)) as original:
        if "source/main.brs" not in original.namelist():
            raise ValueError("Requested commit has no source/main.brs entry point.")
        manifest = original.read("manifest").decode("utf-8")
        for field, number in zip(
            ("major_version", "minor_version", "build_version"), version.split(".")
        ):
            manifest, count = re.subn(
                rf"(?m)^{field}=[^\r\n]*", f"{field}={number}", manifest
            )
            if count != 1:
                raise ValueError(f"Manifest must define {field} exactly once.")

        output = Path(output)
        output.mkdir(parents=True, exist_ok=True)
        archive = output / "twoku.zip"
        with zipfile.ZipFile(archive, "w") as packaged:
            for item in original.infolist():
                data = manifest.encode("utf-8") if item.filename == "manifest" else original.read(item)
                packaged.writestr(item, data)
        with zipfile.ZipFile(archive) as packaged:
            if packaged.testzip() is not None:
                raise ValueError("Generated ZIP failed its integrity check.")

    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / "twoku.zip.sha256").write_text(f"{checksum}  twoku.zip\n", encoding="utf-8")
    return {"sha": sha, "version": version, "tag": f"v{version}"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("commit")
    parser.add_argument("version")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        result = package_release(args.commit, args.version, args.output)
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Packaging failed: {error}\n")
    for key, value in result.items():
        print(f"{key}={value}")


if __name__ == "__main__":
    main()
