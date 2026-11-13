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

# One asset for each distinct dhikr, even when it is repeated across groups.
# Manifest keeps per-screen positions and their independent counter state.
seen = {}
manifest = []
for group_index, group in enumerate(data):
    paths = []
    manifest.append(paths)
    for item_index, item in enumerate(group["items"]):
        content = item["text"]
        if content in seen:
            paths.append(seen[content])
            continue
        filename = f"dhikr_{len(seen):02d}.webp"
        seen[content] = filename
        paths.append(filename)
        is_short_surah = item["source"] in {"سورة الإخلاص", "سورة الفلق", "سورة الناس"}
        is_quran_card = is_short_surah or item["source"] == "سورة البقرة: 255"
        title = ("آية الكرسي" if item["source"] == "سورة البقرة: 255"
                 else item["source"] if item["source"].startswith("سورة")
                 else "ذِكْرٌ وَدُعَاءٌ")
        # The full verified original stays in azkar_data.json. For the image
        # remove only the Ayat al-Kursi title prefix, never the verse itself.
        if item["source"] == "سورة البقرة: 255":
            content = content.split(": ", 1)[1]
        width = 1200
        scratch = Image.new("RGB", (width, 20), "#F1E3C6")
        draw = ImageDraw.Draw(scratch)
        body_font = None
        lines = []
        for size in ((76, 72, 68, 64, 60, 56, 52, 48, 44) if is_quran_card else (68, 64, 60, 56, 52, 48, 44, 40)):
            ft = font(size)
            candidate = lines_of(content, draw, ft, width - 120)
            if len(candidate) <= (11 if is_quran_card else 9):
                body_font = ft
                lines = candidate
                break
        if body_font is None:
            body_font = font(40)
            lines = lines_of(content, draw, body_font, width - 120)
        line_height = int(body_font.size * 1.8)
        body_offset = 130 if is_short_surah else 0
        height = max(520, 260 + body_offset + line_height * len(lines) + 125)
        card = Image.new("RGB", (width, height), "#F1E3C6")
        d = ImageDraw.Draw(card)
        ink = "#241F18"
        d.line((18, 17, width-18, 17), fill="#AF9980", width=2)
        d.text((width//2, 52), title, fill=ink,
               font=font(64 if is_quran_card else 54), anchor="mt", direction="rtl")
        d.line((18, 148, width-18, 148), fill="#AF9980", width=2)
        if is_short_surah:
            d.text((width//2, 183), "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                   fill=ink, font=font(60), anchor="mt", direction="rtl")
        top = 205 + body_offset + max(
            0, (height - 340 - body_offset - line_height * len(lines))//2)
        for line in lines:
            d.text((width//2, top), line, fill=ink, font=body_font, anchor="mt", direction="rtl")
            top += line_height
        d.line((18, height-52, width-18, height-52), fill="#AF9980", width=2)
        d.text((width//2, height-30), item["source"], fill="#63533D",
               font=font(24), anchor="mm", direction="rtl")
        target = out / filename
        card.save(target, format="WEBP", quality=94, method=6)
        assert target.stat().st_size > 1000
# Do not ship leftovers from a previous workflow run.
for stale in out.glob("g*_a*.webp"):
    stale.unlink()
(out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False), encoding="utf-8")
total = sum(len(group["items"]) for group in data)
print(f"Generated {len(seen)} unique image cards for {total} adhkar entries (duplicates reused).")
