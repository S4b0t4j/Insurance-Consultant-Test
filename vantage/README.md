# VANTAGE v6: offline prospect dashboard

One file: `VANTAGE.html` (about 415 KB). You can email it as a single attachment. It needs no internet, hosting, API key or install. It runs in Edge from a local folder and works alongside MPower; it does not connect to MPower.

## Setup
1. Save `VANTAGE.html` anywhere on your work PC (for example `Documents\VANTAGE\`).
2. Double-click it to open it in Edge.
3. If a yellow bar says saving is blocked, your browser policy won't keep data between sessions. In that case use **Import / Export > Download backup** before every close.

## Where things are
| Screen | What it's for |
|---|---|
| Dashboard | Pipeline totals by stage and state |
| Pipeline | Account list. Click an account to see its summary strip and the Intel, Activity, Network and Outreach tabs |
| Map | State map with a pin per account (exact Lat/Lng, or the ZIP code center). Click a state to zoom; scroll to zoom; drag to pan |
| Activity | Touch counts; a weekly touches chart (last 8 weeks, conversations vs attempts); overdue, due soon, "outreach made, no conversation yet", assigned-touch progress and never-touched accounts; a one-on-one summary you can copy; the task list |
| Network | Centers of influence (COI): people not tied to one account, who introduced whom, and which accounts they connect to |
| Import / Export | Excel import with a review step, Excel export, full backup and restore |
| Guide | The full tutorial, built in. Use Print / Save as PDF to share it (`VANTAGE_Guide.pdf` is a ready copy) |
| **+ Log Touch** (sidebar, always visible) | Log a call, email, LinkedIn message, meeting, event or text against any account or COI. Only Type is needed; everything else is optional |

## Daily flow
1. **Log touches as they happen** with + Log Touch. Log attempts too, such as voicemails, no answers and emails with no reply. That's what shows effort on accounts that haven't responded.
2. **Got a summary from somewhere else?** Go to Activity > **Paste summary**. Paste lines like `2026-11-18 | Acme | Jane Smith | Call | Voicemail | Follow-up | note`, review them, then save. "Copy Lenwork prompt" gives you text that tells Lenwork to produce exactly this format from your Outlook and Teams.
3. **Before a one-on-one:** go to Activity > One-on-one summary, pick the dates, and click **Copy summary**.
4. **A manager asks about one account:** open the account and click **Copy status update**.
5. **Someone changes roles:** go to the account > Network > the contact's card > **Title change**. This records the history, flags them as new in role, and puts the change in the summary strip and the status update. It is logged as a note, not counted as a touch.
6. **Weekly:** Import / Export > **Download backup** (restores everything) and **Export Master Excel** (readable master file).

## Touch plans (optional, per account)
On the account's Activity tab you can set:
- **Frequency:** weekly, every 2 weeks, monthly, quarterly or a custom number of days. The next touch date is calculated from the last touch, and you can type over it.
- **Assigned touches:** a manager-assigned target, for example 8, counted from a start date.

Nothing is set by default. The dashboard does not assume any activity requirement.

## Research prompts
On the Intel tab, the prompt generator builds the prompt. Run it in LenAI or Claude, paste the answer into the box underneath, and click **Fill hook & displacement**.

## Excel
- **Import:** the review screen shows new companies, blank fields that will be filled, and conflicts. Nothing changes until you click Apply. Blank cells never erase data.
- **Export:** gives you Prospects, Activity, Contacts and Network sheets. Re-importing the export updates prospects and activity. Use the backup file to restore contacts and COIs.
- Accepts .xlsx and .csv. Old .xls files need to be re-saved as .xlsx first.

## Phones
The layout works on a phone screen. However, data stays in the browser where it was entered, so notes typed on a phone do not reach the laptop copy. Whether the file may be opened on a personal phone at all is a Marsh security question this dashboard doesn't answer. The route that's available today for notes taken away from the laptop: jot the note in Teams or an email to yourself, then bring it in with **Paste summary** (by hand or through a Lenwork scan).

## Editing the dashboard with Claude
See `HANDOFF_PROMPT.md`.

## Credits (embedded data)
- tiny-inflate (MIT, Devon Govett)
- us-atlas state outlines (ISC, Mike Bostock), simplified
- us-zips ZIP code centers (MIT, derived from US Census ZCTAs)
