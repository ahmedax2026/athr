#!/usr/bin/env python3
"""Bundle the three CC BY 4.0 developer-recorded athans (not IslamWeb clips).

Recording author: nandxorandor/Athan, licensed CC BY 4.0.
See assets/adhan/ATTRIBUTION.txt for credit.
"""
from pathlib import Path
import urllib.request

revision = "ad2bf1799add51cca4aaf1f123b1c212378c7786"
root = Path(__file__).resolve().parents[1]
base = f"https://raw.githubusercontent.com/nandxorandor/Athan/{revision}/app/src/main/assets/athan"
sources = {
    "adhan_voice_1": f"{base}/developer/Developer_Athan-1.mp3",
    "adhan_voice_2": f"{base}/developer/Developer_Athan-2.mp3",
    "adhan_fajr": f"{base}/fajr/Developer_Athan-3_Fajr.mp3",
}
dart_assets = root / "assets" / "adhan"
android_raw = root / "android" / "app" / "src" / "main" / "res" / "raw"
dart_assets.mkdir(parents=True, exist_ok=True)
android_raw.mkdir(parents=True, exist_ok=True)
for name, url in sources.items():
    request = urllib.request.Request(url, headers={"User-Agent": "Athr-Adhan-Credit/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response:
        audio = response.read()
    if not audio.startswith(b"ID3") and audio[:2] != b"\xff\xfb" and audio[:2] != b"\xff\xf3":
        raise RuntimeError(f"Unexpected MP3 data: {name}")
    if len(audio) < 50000:
        raise RuntimeError(f"Truncated adhan: {name}")
    for dest in (dart_assets / f"{name}.mp3", android_raw / f"{name}.mp3"):
        dest.write_bytes(audio)
    print(f"{name}: {len(audio):,} bytes")
print("Downloaded 3 attributed CC BY 4.0 recordings for offline preview/notifications.")
