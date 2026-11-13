#!/usr/bin/env python3
"""Inline the Vite Quran build into one local HTML asset for Android WebView.

Avoid file:// ES-module/CORS loading failures and embed the Uthmani font.
"""
from pathlib import Path
import base64
import mimetypes
import re

root = Path(__file__).resolve().parents[1]
dist = root / "assets" / "react_quran"
html_file = dist / "index.html"
html = html_file.read_text(encoding="utf-8")

def css_asset_url(match):
    raw = match.group(1).strip().strip("'\\"")
    if raw.startswith(("data:", "http:", "https:", "#")):
        return match.group(0)
    path = (css_path.parent / raw.split("?", 1)[0]).resolve()
    if not path.is_file() or not path.is_relative_to(dist.resolve()):
        raise RuntimeError(f"Missing or unsafe Quran font/asset: {raw}")
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"url(data:{mime};base64,{encoded})"

css_links = re.findall(r'<link[^>]+href="([^"]+\\.css)"[^>]*>', html)
scripts = re.findall(r'<script[^>]+src="([^"]+\\.js)"[^>]*></script>', html)
if len(css_links) != 1 or len(scripts) != 1:
    raise RuntimeError(f"Expected exactly one CSS + JS Vite output, got {css_links}, {scripts}")
css_url = css_links[0]
css_path = (dist / css_url.removeprefix("./").removeprefix("/")).resolve()
css = css_path.read_text(encoding="utf-8")
css = re.sub(r'url\\(([^)]*)\\)', css_asset_url, css)
js_url = scripts[0]
js_path = (dist / js_url.removeprefix("./").removeprefix("/")).resolve()
js = js_path.read_text(encoding="utf-8")
if re.search(r'(?m)^\\s*(?:import|export)\\s', js):
    raise RuntimeError("External ES module imports remain in React Quran bundle")
html = re.sub(r'<link[^>]+href="[^"]+\\.css"[^>]*>', lambda _: "<style>" + css + "</style>", html, count=1)
html = re.sub(r'<script[^>]+src="[^"]+\\.js"[^>]*></script>', lambda _: "<script type=\\\"module\\\">" + js.replace("</script>", "<\\/script>") + "</script>", html, count=1)
if 'assets/' in html[:1000]:
    raise RuntimeError("Unresolved external web assets in local Quran page")
html_file.write_text(html, encoding="utf-8")
print(f"Offline Quran HTML ready: {html_file.stat().st_size:,} bytes (JS, CSS, font inlined)")
