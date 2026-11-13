#!/usr/bin/env python3
"""Bundle Quran Tajweed Engine's MIT-licensed offline data for Flutter."""
from pathlib import Path
import json
import urllib.request

base = "https://raw.githubusercontent.com/TheAbubakrAbu/Quran-Tajweed-Engine/main/data/"
out = Path("assets/tajweed")
out.mkdir(parents=True, exist_ok=True)
for name in ("quran.json", "juz.json", "reciters.json", "tajweed-rules.json", "tajweed-annotations.json"):
    request = urllib.request.Request(base + name, headers={"User-Agent": "Athr-Quran-Builder/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
        data = response.read()
    json.loads(data)
    (out / name).write_bytes(data)
quran = json.loads((out / "quran.json").read_text(encoding="utf-8"))
assert len(quran) == 114 and sum(len(s["ayahs"]) for s in quran) == 6236
print("Bundled verified Quran Tajweed Engine data for offline reading")
