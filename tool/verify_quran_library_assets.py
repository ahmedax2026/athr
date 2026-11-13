#!/usr/bin/env python3
"""Ensure Quran Library 5.0.1's core offline JSON assets reach Flutter.

Some published package artifacts or build environments may not contain the
required gzip assets. Populate only missing/corrupted files from a pinned,
official upstream commit before Flutter asset bundling. Fail closed if the
data cannot be verified: never ship a Quran screen that crashes on launch.
"""
from __future__ import annotations
import gzip
import hashlib
import json
import pathlib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE_COMMIT = "c9297f4b8d85ef9bcf7fdf45101d4fc460505cee"
FILES = {
    "quranV4.json.gz": ("72add5079b894e2e3582d953fec55847371b4b91", 745654),
    "qpc-v4.json.gz": ("8bef6976b18bef1a4ca7ab2e984b527ad7ee235a", 1339118),
    "qpc-hafs-word-by-word.json.gz": ("0ccf88d39e26b7d8dc82003770a37d79d769cdd9", 1664258),
    "qpc_v4_ayah_info.json.gz": ("294847b1086ee1c9ae1005c9d9f72f35c69eca47", 91434),
    "surahs_name.json.gz": ("70acf9138b0a70450b7ef7be88b0ff141ccfbe39", 86940),
}


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def check_gzip(data: bytes, name: str) -> None:
    value = json.loads(gzip.decompress(data).decode("utf-8-sig"))
    if not isinstance(value, (dict, list)) or not value:
        raise ValueError(f"Invalid or empty Quran metadata: {name}")


def main() -> None:
    config = json.loads((ROOT / ".dart_tool/package_config.json").read_text())
    package = next((p for p in config["packages"] if p["name"] == "quran_library"), None)
    if package is None:
        raise RuntimeError("quran_library not resolved by flutter pub get")
    root_uri = package["rootUri"]
    if root_uri.startswith("file://"):
        from urllib.parse import urlparse, unquote
        folder = pathlib.Path(unquote(urlparse(root_uri).path))
    else:
        folder = (ROOT / ".dart_tool" / root_uri).resolve()
    dest = folder / "assets" / "jsons"
    dest.mkdir(parents=True, exist_ok=True)
    for name, (expected_sha, expected_size) in FILES.items():
        path = dest / name
        payload = path.read_bytes() if path.exists() else b""
        if payload:
            try:
                check_gzip(payload, name)
                print(f"Valid bundled Quran data: {name} ({len(payload):,} bytes)")
                continue
            except Exception as exc:
                print(f"Replacing invalid {name}: {exc}")
        url = (
            "https://raw.githubusercontent.com/alheekmahlib/quran_library/"
            f"{SOURCE_COMMIT}/assets/jsons/{name}"
        )
        print(f"Restoring missing {name} from pinned official upstream source")
        with urllib.request.urlopen(url, timeout=90) as response:
            payload = response.read()
        if len(payload) != expected_size or git_blob_sha(payload) != expected_sha:
            raise RuntimeError(f"Quran asset integrity verification failed: {name}")
        check_gzip(payload, name)
        path.write_bytes(payload)
        print(f"Verified Quran data: {name} ({len(payload):,} bytes)")

    pubspec = (folder / "pubspec.yaml").read_text()
    if "assets/jsons/" not in pubspec:
        raise RuntimeError("quran_library pubspec does not declare assets/jsons/")
    print("All mandatory quran_library offline assets verified")


if __name__ == "__main__":
    main()
