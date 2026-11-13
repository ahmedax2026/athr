#!/usr/bin/env python3
"""Generate RTL illustrated adhkar cards from existing approved app text.
Uses Pillow/RAQM for shaping instead of image AI (which can alter sacred text).
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, features

assert features.check("raqm"), "Arabic text shaping with libraqm is required"
root = Path(__file__).resolve().parents[1]
data = json.loads((root / "tool/azkar_data.json").read_text(encoding="utf-8"))
out = root / "assets/azkar"
out.mkdir(parents=True, exist_ok=True)
f_candidates = list((root / "react_quran/node_modules/react-quran").rglob("*.ttf"))
f_candidates = sorted(f_candidates, key=lambda p: (0 if "uthman" in p.name.lower() else 1, str(p)))
fallback = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
font_path = f_candidates[0] if f_candidates else fallback
assert font_path.exists(), f"Missing Arabic font {font_path}"

def font(size):
    return ImageFont.truetype(str(font_path), size, layout_engine=ImageFont.Layout.RAQM)

def text_width(draw, value, ft):
    return draw.textbbox((0, 0), value, font=ft, direction="rtl")[2]

def lines_of(text, draw, ft, maxw):
    words = text.split()
    lines = []
    current = ""
    for word in words:
        proposed = (current + " " + word).strip()
        if current and text_width(draw, proposed, ft) > maxw:
            lines.append(current)
            current = word
        else:
            current = proposed
    if current:
        lines.append(current)
    return lines

for group_index, group in enumerate(data):
    for item_index, item in enumerate(group["items"]):
        content = item["text"]
        title = item["source"] if item["source"].startswith("سورة") else group["title"]
        width = 1200
        scratch = Image.new("RGB", (width, 20), "#F1E3C6")
        draw = ImageDraw.Draw(scratch)
        body_font = None
        lines = []
        for size in (68, 64, 60, 56, 52, 48, 44, 40):
            ft = font(size)
            candidate = lines_of(content, draw, ft, width - 120)
            if len(candidate) <= 9:
                body_font = ft
                lines = candidate
                break
        if body_font is None:
            body_font = font(40)
            lines = lines_of(content, draw, body_font, width - 120)
        line_height = int(body_font.size * 1.8)
        height = max(520, 260 + line_height * len(lines) + 125)
        card = Image.new("RGB", (width, height), "#F1E3C6")
        d = ImageDraw.Draw(card)
        ink = "#241F18"
        d.line((18, 17, width-18, 17), fill="#AF9980", width=2)
        d.text((width//2, 54), title, fill=ink, font=font(54), anchor="mt", direction="rtl")
        d.line((18, 148, width-18, 148), fill="#AF9980", width=2)
        top = 205 + max(0, (height - 340 - line_height * len(lines))//2)
        for line in lines:
            d.text((width//2, top), line, fill=ink, font=body_font, anchor="mt", direction="rtl")
            top += line_height
        d.line((18, height-52, width-18, height-52), fill="#AF9980", width=2)
        d.text((width//2, height-30), group["title"], fill="#63533D",
               font=font(24), anchor="mm", direction="rtl")
        target = out / f"g{group_index}_a{item_index}.webp"
        card.save(target, format="WEBP", quality=91, method=5)
        assert target.stat().st_size > 1000
print(f"Generated {sum(len(group['items']) for group in data)} Arabic adhkar cards from {font_path.name}.")
