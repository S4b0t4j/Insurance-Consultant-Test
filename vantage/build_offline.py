#!/usr/bin/env python3
"""Build the offline VANTAGE dashboard.

Usage:  python3 vantage/build_offline.py
Input:  vantage/VANTAGE_source.html  (small, editable)
Output: vantage/VANTAGE_offline.html (single file, no network needed)

Embeds d3, topojson-client, SheetJS and the US map data from vantage/vendor/
so the dashboard runs from file:// with no internet access.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'VANTAGE_source.html')
OUT = os.path.join(HERE, 'VANTAGE_offline.html')
V = os.path.join(HERE, 'vendor')

def rd(name):
    with open(os.path.join(V, name), encoding='utf-8') as f:
        return f.read()

def script(label, code):
    code = re.sub(r'</(script)', r'<\\/\1', code, flags=re.I)
    return '<script>/* OFFLINE BUNDLE: %s */\n%s\n</script>' % (label, code)

CDN_TAGS = '''<script src="https://cdn.sheetjs.com/xlsx-0.20.3/package/dist/xlsx.full.min.js" async></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/d3/7.8.5/d3.min.js" async></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/topojson/3.0.2/topojson.min.js" async></script>'''

bundle = '\n'.join([
    script('d3 7.8.5 (ISC)', rd('d3.min.js')),
    script('topojson-client 3.1.0 (ISC)', rd('topojson-client.min.js')),
    script('SheetJS xlsx 0.18.5 (Apache-2.0)', rd('xlsx.full.min.js')),
    script('us-atlas 3.0.1 states (ISC)', 'window.US_STATES_10M=' + rd('states-10m.json').strip() + ';'),
    script('us-atlas 3.0.1 counties (ISC)', 'window.US_COUNTIES_10M=' + rd('counties-10m.json').strip() + ';'),
])

REPLACEMENTS = [
    (CDN_TAGS, bundle),
    ("  // Load US TopoJSON from CDN (JS-only, no map tiles)\n"
     "  fetch('https://cdn.jsdelivr.net/npm/us-atlas@3/states-10m.json')\n"
     "    .then(function(r){return r.json();})\n",
     "  // US TopoJSON is embedded in this file (offline, no network)\n"
     "  Promise.resolve(window.US_STATES_10M)\n"),
    ("    fetch('https://cdn.jsdelivr.net/npm/us-atlas@3/counties-10m.json')\n"
     "      .then(function(r){return r.json();})\n",
     "    Promise.resolve(window.US_COUNTIES_10M)\n"),
]

with open(SRC, encoding='utf-8') as f:
    html = f.read()
for old, new in REPLACEMENTS:
    n = html.count(old)
    if n != 1:
        sys.exit('BUILD FAILED: expected 1 match, found %d for:\n%s' % (n, old[:120]))
    html = html.replace(old, new)
if re.search(r'(src=|fetch\()\s*["\']https?://', html):
    sys.exit('BUILD FAILED: a network dependency is still present')
with open(OUT, 'w', encoding='utf-8') as f:
    f.write(html)
print('Built %s (%.1f MB)' % (OUT, os.path.getsize(OUT) / 1e6))
