#!/usr/bin/env python3
"""Convert approved uploaded image bytes to real lossless WebP for the APK.

The uploaded files remain untouched in GitHub. This runs only in the temporary
Android build checkout and does not redraw or transcribe any Quranic text.
"""
import io
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
folder = root / "assets" / "azkar"
manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
files = sorted(set(name for group in manifest for name in group))
for name in files:
    if not name.endswith(".webp"):
        raise RuntimeError("Please use .webp filenames for approved cards: " + name)
    path = folder / name
    original = path.read_bytes()
    with Image.open(io.BytesIO(original)) as image:
        image.load()
        width, height = image.size
        detected = image.format
        if detected != "WEBP":
            # The upload may have been renamed .webp without conversion.
            image.convert("RGB").save(path, format="WEBP", lossless=True, method=6)
    with Image.open(path) as checked:
        checked.load()
        if checked.format != "WEBP" or checked.size != (width, height):
            raise RuntimeError("Image conversion failed: " + name)
    print(f"{name}: {detected} -> WEBP, {width}x{height}")
print(f"Validated {len(files)} actual WebP image files for the APK.")
