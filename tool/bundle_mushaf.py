#!/usr/bin/env python3
"""Bundle surah-to-page metadata only; Quran pages use the Ottoman text reader."""
from pathlib import Path
import json
import urllib.request

base = "https://raw.githubusercontent.com/batoulapps/quran-svg/main/surah.json"
request = urllib.request.Request(base, headers={"User-Agent": "Athr-Quran-Index/1.0"})
with urllib.request.urlopen(request, timeout=90) as response:
    metadata = json.load(response)
assert len(metadata) == 114
out = Path("assets/mushaf")
out.mkdir(parents=True, exist_ok=True)
(out / "surah_pages.json").write_text(
    json.dumps(
        [{"number": s["number"], "name": s["nameArabic"], "page": s["pageNumber"]}
         for s in metadata],
        ensure_ascii=False,
    ), encoding="utf-8")
print("Quran page index ready; no mushaf page images bundled.")
