#!/usr/bin/env python3
"""Build offline, print-faithful Madinah mushaf page images from batoulapps/quran-svg.
Artwork source: https://github.com/batoulapps/quran-svg (MIT).
Underlying Quran artwork credited to King Fahd Glorious Quran Printing Complex.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
from io import BytesIO
from pathlib import Path
import json
import urllib.request
import cairosvg
from PIL import Image

BASE = "https://raw.githubusercontent.com/batoulapps/quran-svg/main"
OUT = Path("assets/mushaf")
OUT.mkdir(parents=True, exist_ok=True)

def download(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Athr-Mushaf-Offline/1.0"})
    with urllib.request.urlopen(req, timeout=90) as r:
        return r.read()

def build_page(n):
    dest = OUT / f"{n:03}.webp"
    # Always rebuild: older pages may have been rendered with a black background.
    svg = download(f"{BASE}/svg/{n:03}.svg")
    png = cairosvg.svg2png(bytestring=svg, output_width=900)
    rendered = Image.open(BytesIO(png)).convert("RGBA")
    # Remove empty SVG margins before composing the paper background.
    # Keep a small safety margin around all printed glyphs and ornaments.
    alpha = rendered.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value > 16 else 0).getbbox()
    if bounds:
        margin = max(10, int(rendered.width * 0.015))
        left, top, right, bottom = bounds
        rendered = rendered.crop((max(0, left - margin), max(0, top - margin),
                                 min(rendered.width, right + margin),
                                 min(rendered.height, bottom + margin)))
    # SVG pages have a transparent background. Converting directly to RGB
    # turns transparency black and makes the dark Quran glyphs invisible.
    image = Image.new("RGB", rendered.size, (255, 252, 242))
    image.paste(rendered, mask=rendered.getchannel("A"))
    image.save(dest, "WEBP", quality=88, method=4)
    assert dest.stat().st_size > 1000, f"Invalid page {n}"

def main():
    metadata = json.loads(download(f"{BASE}/surah.json"))
    assert len(metadata) == 114
    (OUT / "surah_pages.json").write_text(json.dumps([
        {"number": s["number"], "name": s["nameArabic"], "page": s["pageNumber"]}
        for s in metadata
    ], ensure_ascii=False), encoding="utf-8")
    with ThreadPoolExecutor(max_workers=10) as pool:
        futures = [pool.submit(build_page, n) for n in range(1, 605)]
        for index, f in enumerate(as_completed(futures), 1):
            f.result()
            if index % 100 == 0:
                print(f"Prepared {index}/604 pages", flush=True)
    assert len(list(OUT.glob("*.webp"))) == 604
    print("604 original-layout mushaf pages bundled for offline reading.")

if __name__ == "__main__":
    main()
