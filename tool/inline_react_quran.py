#!/usr/bin/env python3
"""Pack React Quran JS, CSS and Uthmani font into one offline HTML file."""
from pathlib import Path
import base64
import mimetypes
import re

dist = Path(__file__).resolve().parents[1] / "assets" / "react_quran"
index = dist / "index.html"
html = index.read_text(encoding="utf-8")


def get_asset(url, relative_to):
    path = (relative_to / url.lstrip("./").split("?", 1)[0]).resolve()
    if not path.is_file() or not path.is_relative_to(dist.resolve()):
        raise RuntimeError(f"Missing or unsafe Quran asset: {url}")
    return path


css_re = r'<link[^>]+href="([^"]+\.css)"[^>]*>'
js_re = r'<script[^>]+src="([^"]+\.js)"[^>]*></script>'
css_refs = re.findall(css_re, html)
js_refs = re.findall(js_re, html)
if len(css_refs) != 1 or len(js_refs) != 1:
    raise RuntimeError(f"Unexpected Vite output: CSS={css_refs}, JS={js_refs}")

css_file = get_asset(css_refs[0], dist)
css = css_file.read_text(encoding="utf-8")


def inline_css_asset(match):
    url = match.group(1).strip().strip("\"'")
    if url.startswith(("data:", "#")):
        return match.group(0)
    if url.startswith(("http:", "https:")):
        raise RuntimeError(f"Quran HTML must not fetch remote assets: {url}")
    file = get_asset(url, css_file.parent)
    mime = mimetypes.guess_type(file.name)[0] or "application/octet-stream"
    return "url(data:" + mime + ";base64," + base64.b64encode(file.read_bytes()).decode("ascii") + ")"


css = re.sub(r'url\(([^)]*)\)', inline_css_asset, css)
js = get_asset(js_refs[0], dist).read_text(encoding="utf-8")
if re.search(r'(?m)^\s*(?:import|export)\s', js):
    raise RuntimeError("Unbundled JavaScript ES module detected")

html = re.sub(css_re, lambda _: "<style>" + css + "</style>", html, count=1)
html = re.sub(js_re, lambda _: '<script type="module">' + js.replace("</script>", "<\\/script>") + "</script>", html, count=1)
if re.search(r'<(?:link|script)[^>]+(?:src|href)="[^"]+assets/', html):
    raise RuntimeError("External script or stylesheet remains")
if "data:font/" not in html:
    raise RuntimeError("Uthmani Quran font was not embedded")
index.write_text(html, encoding="utf-8")
print(f"Offline React Quran asset: {index.stat().st_size:,} bytes")
