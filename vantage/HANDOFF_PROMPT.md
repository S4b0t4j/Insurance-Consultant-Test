You are editing VANTAGE v5, an offline prospect pipeline dashboard for a commercial insurance producer. It is a single file, VANTAGE.html, written in vanilla JavaScript with no frameworks. It runs from a local folder (file://) in corporate Microsoft Edge, with no internet, no server and no API keys.

## Files
- `VANTAGE.html`: the only file you edit. It is attached.
- `vantage-libs.js`: sits in the same folder and is loaded with `<script src="vantage-libs.js">`. It defines `d3`, `topojson`, `XLSX` (SheetJS), `US_STATES_10M`, `US_COUNTIES_10M` and `ZIP_CENTROIDS` ({"02134":[lat,lng]}). You never see or edit this file. Assume those globals exist, and always guard with `typeof X !== 'undefined'`.

## Hard rules
1. Offline only. Never add a CDN script, `fetch()`, web font, external image, analytics, or anything else that needs the internet or an API key.
2. Never put a literal line break inside a JavaScript string. Use `\n`.
3. Keep everything in VANTAGE.html. Do not split it into more files.
4. Do not use setInterval/setTimeout for startup. Startup is the `DOMContentLoaded` handler (search `// ===== BOOT =====`), where each call is wrapped in its own try/catch.
5. All localStorage access stays inside try/catch. `saveState()` returns true or false.
6. Escape any user or Excel data with `esc()` before putting it into HTML.

## How the data works
- `PROSPECTS` (near the top of the script): starting records. Most data arrives through Excel import instead.
- `STATE` (localStorage key `vantage_ww_v4`): everything the user changes. This includes `STATE.records`, which holds the full record of any prospect added or updated by import or by Add Prospect. These records are merged into PROSPECTS on load.
- `FIELDS` (search `// ===== DATA FIELDS`): **the single source of truth for every column.** Import, the review screen, Excel export, the template and the Recognized Columns list are all generated from it.
  - To add a new column, add one entry to FIELDS. Use `store:'rec'` to save the value on the record, `store:'state'` with a `bucket` to save it in `STATE[bucket][id]`, or `store:'net'` to save it in `STATE.network[id]`. List the header spellings to accept in `aliases` (lowercase, letters and digits only).
  - If the new field must be visible in the UI, also render it where it should appear (the detail panel tabs are `renderIntelTab`, `renderNetworkTab` and so on). Read and write it with `getVal(p,key)` / `setVal(p,key,val)`, then call `upsertRecord(p)` and `saveState()`.
- Map pins come from `geoOf(p)`: exact lat/lng if present, otherwise the ZIP code center, otherwise the 3-digit ZIP area.
- Import flow: `processIntakeFile` → `buildImportPlan` → `renderImportReview` (the user approves) → `confirmIntake`. Blank cells never overwrite data.
- After any change to data, call `refreshAfterDataChange()`.

## How to deliver changes
- Make the smallest change that does the job. Do not reformat or reorder unrelated code.
- Return your changes as exact find-and-replace pairs: "FIND this exact text" and "REPLACE with". Each FIND must appear exactly once in the file. Only return the full file if asked.
- Say which functions you changed and why.

## Test checklist (tell the user to run it after applying your edit)
1. Open VANTAGE.html in Edge and press F12, then go to Console. There must be no red errors.
2. Click every tab: Dashboard, Pipeline, Map, To-Do, Import / Export. Each one should show content.
3. On Map, state outlines and pins should appear, and clicking a state should show its counties.
4. Import a small test Excel file. The review screen should appear, and Apply should work.
5. Export Master Excel, then re-import that same file. The review should say every company is unchanged.

If any step fails, the user should send you the exact Console error.
