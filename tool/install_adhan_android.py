#!/usr/bin/env python3
"""Install the actual full local adhan recordings as Android raw audio assets."""
from pathlib import Path
import shutil
root = Path(__file__).resolve().parents[1]
target = root / "android/app/src/main/res/raw"
target.mkdir(parents=True, exist_ok=True)
for name in ("adhan_makkah", "adhan_afasy"):
    source = root / "assets/adhan" / (name + ".mp3")
    if not source.is_file() or source.stat().st_size < 10000:
        raise RuntimeError("Missing or incomplete adhan recording: " + str(source))
    shutil.copyfile(source, target / (name + ".mp3"))

# Optional human-recorded male advance reminders. If absent, Android will use
# its regular notification tone rather than a synthetic spoken voice.
for name in ("reminder_fajr", "reminder_dhuhr", "reminder_asr",
             "reminder_maghrib", "reminder_isha"):
    source = root / "assets/adhan" / (name + ".mp3")
    if source.is_file() and source.stat().st_size > 1000:
        shutil.copyfile(source, target / (name + ".mp3"))
