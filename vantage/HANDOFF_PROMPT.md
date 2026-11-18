You are editing VANTAGE v6, an offline prospect pipeline dashboard for a commercial insurance producer at Marsh. It is a single file, VANTAGE.html, written in vanilla JavaScript with no frameworks and no libraries. It runs from a local file (file://) in corporate Microsoft Edge, with no internet, no server and no API keys. The producer also uses MPower. There is NO integration with MPower; do not add one.

## How the file is laid out
1. `<style>`: CSS. Additions from v6 are at the end, marked `/* ===== v6 additions ===== */`.
2. HTML: the sidebar and the screens `scrDash`, `scrPipeline` (with the `detailPanel`), `scrMap`, `scrTodo` (the Activity screen), `scrCoi` (the Network screen), `scrGuide` (the built-in tutorial: update it when features change) and `scrIntake` (Import / Export).
3. The main `<script>`: all app logic. This is the only part you edit.
4. A final `<script>` marked `DATA SECTION`: a deflate decoder, the state outlines (`VX_STATES`) and the packed ZIP code centers (`VX_ZIPS`). **Never edit it.** The user will usually not send it to you; assume it exists.

## Hard rules
1. The file must stay under 500 KB, because it is emailed as one attachment. It is about 415 KB now. Do not embed libraries, fonts or images.
2. Offline only. No CDN, `fetch()`, web fonts, external images, or anything else that needs the internet or an API key.
3. Never put a literal line break inside a JavaScript string. Use `\n`.
4. Do not use setInterval/setTimeout for startup. Startup is the `DOMContentLoaded` handler (`// ===== BOOT =====`), where each call is wrapped in its own try/catch.
5. All localStorage access goes through `saveState()`, which returns true or false and never throws.
6. Escape data with `esc()` before putting it into HTML. Use `jsq()` for values inside inline onclick strings.
7. Do not invent stage definitions, activity requirements, touch targets or security permissions. Those settings belong to the user.

## Data model (all of it lives in `STATE`, localStorage key `vantage_ww_v4`)
- `PROSPECTS`: account records. Records added through import or Add Prospect are saved in `STATE.records` and merged into PROSPECTS on load.
- `FIELDS` (`// ===== DATA FIELDS`): the single source of truth for every account column used by import, review, export and the template. To add a column, add one entry there.
- `STATE.activity[accountOrCoiId]`: an array of `{type, date, contact, outcome, topic, notes, info?}`.
  - `ACT_TYPES`, `OUTCOMES` and `STATE.settings.topics` define the dropdowns.
  - `actKind(a)` returns convo, attempt or other.
  - `isTouch(a)` is false for `info` entries such as a recorded org change.
  - Use `acctStats(id, fromIso)` for counts.
- `STATE.contacts[accountId]`: an array of `{name, title, strength, status:'current'|'new'|'left', key, note, linkedin, history:[{date,from,to,note}]}`.
- `STATE.cois`: an array of `{id, name, org, strength, introBy, links:[accountIds], notes}`. COI touches are stored in `STATE.activity[coi.id]`.
- `STATE.cadence[accountId]`: `{every: days, target: n, since: date, due: overrideDate}`. Use `nextDue(id)` and `targetProgress(id)`.
- `STATE.network[accountId]`: the per-account `{dm, coi, intro}` text fields.
- After changing data, call `saveState()`, then `afterActivityChange(id)` (activity, contacts, COIs) or `refreshAfterDataChange()` (accounts).

## Key functions
- `openActivityModal(id, preset)`: the single Log Touch window.
- `renderGlance(p)`: the account summary strip.
- `statusText(id)`: builds the copyable status update.
- `renderActivityScreen()`, `followUpBuckets()`, `reportText(from, to)`: the Activity screen and the one-on-one summary.
- `openPasteModal()`, `parsePaste()`, `applyPaste()`: paste import. `LENWORK_PROMPT` holds the expected line format.
- `pgApplyResult(id)`: fills the hook and displacement angle from a pasted research answer.
- `VX.readFile` and `VX.downloadXlsx`: the built-in Excel/CSV reader and writer.
- `geoOf(p)` and `VX.project`: map pin location.
- `downloadBackup()` and `restoreBackup()`: full backup and restore.

## How to deliver changes
- Make the smallest change that works. Keep the existing look; reuse the existing CSS classes (`vx-card`, `vx-mini`, `vx-pill`, `cmd-btn`, `cmd-ghost`, `fi`, `fg`, `fg-grid`).
- Return the changes as exact find-and-replace pairs: "FIND this exact text" and "REPLACE with". Each FIND must appear exactly once in the file. Only return the full file if asked.
- List the functions you changed, and anything that is still unverified.

## Test checklist (tell the user to run it after applying your edit)
1. Open VANTAGE.html in Edge and press F12, then go to Console. There must be no red errors.
2. Click every sidebar item. Each screen should show content.
3. Click + Log Touch and save a touch. It should appear on the account's Activity tab and on the Activity screen.
4. On the Map, pins should appear, and clicking a state should zoom in.
5. Export Master Excel, then re-import that file. The review should say every company is unchanged.
6. Download a backup, then restore it. The data should be unchanged.
7. Check the file size in File Explorer: it must be under 500 KB.

If any step fails, the user should send you the exact Console error.
