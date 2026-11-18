You are working on VANTAGE, a single-file HTML prospect pipeline dashboard (vanilla JS, no frameworks). It must work fully offline from file:// in MMC corporate Edge. No hosting, no CDN, no network calls.

## Files (in vantage/)
- `VANTAGE_source.html`: the ONLY file you edit. Small and readable.
- `build_offline.py`: run `python3 vantage/build_offline.py` after every edit. It embeds the libraries and map data from `vendor/` and writes `VANTAGE_offline.html`. It fails loudly if any network dependency remains.
- `VANTAGE_offline.html`: generated, 2.2 MB, the file users open. Never edit it directly and never read it into context.
- `vendor/`: d3 7.8.5, topojson-client 3.1.0, SheetJS xlsx 0.18.5, us-atlas 3.0.1 states and counties. Do not modify.

## Architecture
- One main inline <script> holds all app logic. A single syntax error anywhere in it kills the whole app: the shell renders but every function is undefined and nav clicks do nothing. This is the #1 failure mode.
- Data source: the `var PROSPECTS = [ ... ]` array near the top of the main script. Find it by searching for that string, not by line number.
- User edits live in `STATE` (localStorage key `vantage_ww_v4`) via `loadState()` / `saveState()`.
- On load, a seed block (search `SEED STATE FROM PROSPECTS DATA`) copies stage, warm, action and notes from each record into STATE, but only where STATE has no value yet. Saved user edits always win over record data.

## PROSPECTS record schema
Required (read by the UI): `id, company, city, state, zip, lat, lng`
Optional, used: `street, stage, warm, action, notes`
Optional, stored but not currently displayed: `contact, title, rev, line, lastTouch, assignedTo`

Value rules:
- `id`: unique string, format `XX-001` where XX = user initials
- `stage`: number or string. 1 = prospect, 2-3 = engaged, 4-5 = proposal, 6 = won, 7+ = lost. Strings accepted: prospect, engaged, proposal, won, lost
- `warm`: number (3+ = warm, below 3 = cold) or string warm / hot / cold
- `lat` / `lng`: numbers, required for the map

## Environment constraints (MMC Edge, file://)
- localStorage may be blocked. All access stays inside try/catch.
- Do not use setInterval/setTimeout chains for boot. Boot is direct synchronous calls inside DOMContentLoaded, each wrapped in its own try/catch.
- `#app` is display:flex in CSS. `#loading` is display:none in CSS. Never rely on JS to show the app.
- Offline only. Never add a CDN script, fetch(), external font or any other network request. If you need a new library, add its minified file to `vendor/` and embed it via `build_offline.py`. Keep the existing `typeof d3 !== 'undefined'` style guards.
- Never put a literal line break inside a JS string. Use `\n`. If you write the file with Python or another tool, make sure `\n` escapes inside JS strings are not converted to real newlines. This exact bug broke v4.7.

## Edit rules
1. Make surgical, exact string replacements. Each target must match exactly once. Do not rewrite large blocks.
2. Do not reformat, minify or reorder unrelated code.
3. Keep the file as a single self-contained HTML file.

## Required verification after every edit (do not skip)
1. Syntax check: extract the main inline <script> contents to a .js file and run `node --check` on it. It must pass.
2. Build: run `python3 vantage/build_offline.py`. It must succeed.
3. Browser check: load `VANTAGE_offline.html` via file:// in headless Chromium (Playwright) with the context set to offline and every non-file request aborted. Capture `pageerror` and console errors. There must be zero errors and zero network requests.
4. Click every nav tab (`#nav-dash`, `#nav-pipeline`, `#nav-map`, `#nav-intake`, `#nav-todo`) and confirm each screen gets class `on`, renders content, and shows no "undefined", "NaN" or "[object" text. On the map tab, confirm state outlines and pins render, and that clicking a state draws its counties.
5. Confirm `#app` is display:flex, `#loading` is display:none, and no setInterval appears in the boot block.
6. Report what you ran and the results. If any check fails, revert that edit and try a narrower replacement.

## To load a new user's data
In `VANTAGE_source.html`, replace only the contents of `var PROSPECTS = [ ... ]` with the new records. Do not touch anything else. Then rebuild and run the full verification above. Update the sidebar name placeholder `[Your Name]` if asked.
