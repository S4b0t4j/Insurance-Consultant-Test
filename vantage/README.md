# VANTAGE v5: offline prospect dashboard

Runs entirely on your work PC. You don't need internet, hosting, an API key, or an install.

## Setup (one time)
1. Put these two files in the **same folder** on your work PC (for example `Documents\VANTAGE\`):
   - `VANTAGE.html`: the dashboard
   - `vantage-libs.js`: map, Excel and ZIP code data. You never edit this file.
2. Double-click `VANTAGE.html`. It opens in Edge.

If the bottom of the screen shows a yellow bar saying `vantage-libs.js` was not found, the two files are not in the same folder.

## Daily workflow (Excel is the master)
1. **Import.** Go to Import / Export and drop in your Excel file.
2. **Review.** The dashboard shows:
   - new companies
   - blank fields it will fill in
   - **conflicts**, where your Excel file differs from what the dashboard already has
   Untick anything you don't want, then click Apply. Nothing changes until you do.
3. **Work.** Update stages, notes and activity in the dashboard.
4. **Export.** Click Export Master Excel and save the file as your new master. Do this at the end of every session. Dashboard data only lives in this browser on this PC.

Rules the import follows:
- Companies are matched by `ID` first, then by company name. "Acme Corp." and "Acme Corporation" count as the same company.
- Blank Excel cells never erase existing data.
- Columns can be in any order. Columns the dashboard doesn't recognize are ignored, so you can keep your own working columns.
- ZIP codes that Excel shortened (2134) are fixed (02134). Full state names (Texas) become abbreviations (TX).

## Map pins
- If a row has `Lat` and `Lng`, the pin goes on that exact spot.
- Otherwise the pin goes on the center of the row's ZIP code. This is built in and works offline.
- No ZIP code means no pin. The review screen shows which pin type each new company will get.

## Filling in missing addresses with Claude (Sonnet 4.6 / 5)
1. Export Master Excel.
2. Upload the file to Claude with the prompt below.
3. Import the file Claude returns and review the changes. Conflicts show up highlighted.

Prompt:

```
Attached is my prospect list. For each row where Street, City, State or ZIP is blank, fill in the company's headquarters address in the US.
Rules:
- Only fill a cell if you are confident. If unsure, leave it blank. Never guess a ZIP.
- Do not change any cell that already has a value.
- Do not rename, add, remove or reorder columns, except: add one column at the end called "Address Source" with a short note on where each filled address came from, or "unsure".
- Keep the ID column exactly as is.
- Return the full file as .xlsx with the same sheet names.
```

The dashboard ignores the extra "Address Source" column, so you can check it in Excel before you import.

## Editing the dashboard with Claude
See `HANDOFF_PROMPT.md`. Only ever give Claude `VANTAGE.html`. Never give it `vantage-libs.js`, which is 3 MB of library code.
