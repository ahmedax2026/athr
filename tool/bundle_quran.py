#!/usr/bin/env python3
"""Bundle an offline Uthmani Quran from the openly licensed Quran JSON snapshot."""
import json
import pathlib
import urllib.request

BASE = "https://quran-json.risanb.com"
OUT = pathlib.Path("assets/quran")
OUT.mkdir(parents=True, exist_ok=True)

def fetch(path):
    request = urllib.request.Request(BASE + path, headers={"User-Agent": "Athr-Quran-Offline-Build/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.load(response)

chapters = fetch("/chapters.json")
quran = fetch("/text/uthmani/quran.json")
if isinstance(chapters, dict):
    chapters = chapters.get("chapters", chapters.get("data"))
if isinstance(quran, dict):
    quran = quran.get("chapters", quran.get("data"))
assert isinstance(chapters, list) and len(chapters) == 114, "Expected 114 chapter metadata records"
assert isinstance(quran, list) and len(quran) == 114, "Expected 114 chapters"
by_id = {int(x.get("id", x.get("number"))): x for x in chapters}
out = []
for index, chapter in enumerate(quran, 1):
    number = int(chapter.get("id", chapter.get("number", index)))
    assert number == index, f"Unexpected surah order: {number}"
    metadata = by_id[number]
    verses = chapter["verses"]
    assert verses, f"Missing verses in surah {number}"
    texts = [v["text"] for v in verses]
    assert all(isinstance(t, str) and t.strip() for t in texts)
    name = metadata.get("name_arabic") or metadata.get("name") or metadata.get("arabic")
    if isinstance(name, dict):
        name = name.get("ar") or name.get("arabic")
    assert isinstance(name, str) and name, f"Missing Arabic surah name {number}"
    out.append({"number": number, "name": name, "ayahs": texts,
                "revelationType": metadata.get("revelation_place", metadata.get("revelationType", ""))})
assert sum(len(s["ayahs"]) for s in out) == 6236, "Expected 6236 verses"
(OUT / "quran.json").write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
print("Bundled 114 surahs and 6236 ayahs for fully offline reading.")
