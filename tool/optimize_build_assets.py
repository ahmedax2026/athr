#!/usr/bin/env python3
"""Optimize only temporary build assets; preserve original repository recordings."""
from pathlib import Path
from PIL import Image, ImageChops
import io
import json
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
folder = root / "assets/azkar"
manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
for name in sorted({name for group in manifest for name in group}):
    path = folder / name
    original = path.read_bytes()
    with Image.open(io.BytesIO(original)) as image:
        image.load()
        # Keep dimensions and exact decoded pixels, including Arabic text.
        mode = "RGBA" if "A" in image.getbands() else "RGB"
        pixels = image.convert(mode)
        candidate = io.BytesIO()
        pixels.save(candidate, format="WEBP", lossless=True, method=6, exact=True)
        data = candidate.getvalue()
        if len(data) < len(original):
            with Image.open(io.BytesIO(data)) as check:
                assert check.size == pixels.size
                assert all(channel.getbbox() is None for channel in ImageChops.difference(pixels, check.convert(mode)).split())
            path.write_bytes(data)
    print(f"{name}: {len(original)} -> {path.stat().st_size} bytes")

def duration(path):
    return float(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(path)
    ], text=True).strip())

for path in sorted((root / "assets/adhan").glob("adhan_*.mp3")):
    before = path.stat().st_size
    seconds = duration(path)
    with tempfile.TemporaryDirectory() as temp:
        out = Path(temp) / "voice.mp3"
        subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y",
            "-i", str(path), "-map", "0:a:0", "-vn", "-ac", "1",
            "-ar", "44100", "-c:a", "libmp3lame", "-b:a", "64k",
            str(out)], check=True)
        assert abs(duration(out) - seconds) < 0.15, "Audio duration changed"
        subprocess.run(["ffmpeg", "-v", "error", "-i", str(out),
            "-f", "null", "-"], check=True)
        if out.stat().st_size < before:
            path.write_bytes(out.read_bytes())
    print(f"{path.name}: {before} -> {path.stat().st_size} bytes; {seconds:.2f}s")
