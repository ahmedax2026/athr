#!/usr/bin/env python3
"""Bind each approved uploaded adhkar image by its content, even after renames.

These are the Git blob hashes of the 17 images supplied by the user. We do
not redraw Quranic text, generate substitute cards, or modify uploaded pixels.
"""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
folder = root / "assets" / "azkar"
sources = {
    "ayat": "deed3ccb6ace352a6a528f0708ec5c4798ff91e0",
    "ikhlas": "a1ef57c2bcca6c5922cddc685710d0379ff8e6d1",
    "falaq": "152fc14425c0e54776a70897611fdff3a8955602",
    "nas": "cfddf16fc0ae792e26a76531df70f4acd4d1b144",
    "01": "4370116525d8bb9e903df5dad4daef10b4114426",
    "02": "628135f169847011a5b68ce48a2acb68dc4cc054",
    "03": "f3df600720e911db6919eb211bcb35b86cdf387c",
    "04": "7fdbe6eee0e8366c9dfcad589f22a9e1211f3382",
    "05": "640f7002be0d6387c31910b9727355d9ddc0a28b",
    "06": "67f24d70dbd4c875805c8846d5a8dbc3583c4c99",
    "07": "cadf7e4a53cc433c030222f0b3f75cf38580cdf1",
    "08": "30462eb8014a2cad1fa7f2718cd40e44e658f223",
    "09": "04b5e7e7a954f98590eebe3689d34842c3ec1d68",
    "10": "594206f6196cdf6efc44b7623a4eac315fde01d5",
    "11": "b05b03f8e8fddd33128c67a68f29f6419ba96c1e",
    "12": "14c6d7829973bc9c4894e77c6ed2f6241144b442",
    "13": "3c77ac10b04d1c61be70c283caccfec10b9280d1",
}
# A shared file is used for every repeated dhikr; counters remain per section.
order = [
    ["ayat", "ikhlas", "falaq", "nas", "01", "02"],
    ["ikhlas", "falaq", "nas", "03", "01"],
    ["04", "05", "06", "07", "08", "09"],
    ["10", "06", "07", "08"],
    ["11"],
    ["12", "13"],
]

def git_blob_sha(payload):
    header = f"blob {len(payload)}\0".encode("ascii")
    return hashlib.sha1(header + payload).hexdigest()

files_by_sha = {}
for candidate in sorted(folder.iterdir()):
    if candidate.is_file() and candidate.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}:
        payload = candidate.read_bytes()
        files_by_sha.setdefault(git_blob_sha(payload), []).append(candidate.name)
missing = {name: sha for name, sha in sources.items() if sha not in files_by_sha}
if missing:
    raise RuntimeError("Approved adhkar image files are missing or were modified: " + ", ".join(missing))
resolved = {name: sorted(files_by_sha[sha])[0] for name, sha in sources.items()}
manifest = [[resolved[key] for key in group] for group in order]
data = json.loads((root / "tool" / "azkar_data.json").read_text(encoding="utf-8"))
assert len(data) == len(manifest)
assert all(len(group["items"]) == len(images) for group, images in zip(data, manifest))
(folder / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Linked {sum(map(len, manifest))} placements to {len(sources)} original images")
for group, images in zip(data, manifest):
    print(f'{group["title"]}: ' + ", ".join(images))
