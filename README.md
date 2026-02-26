# Insurance-Consultant-Test
Testing RFP Applcation

---

# GovWin IQ Opportunity Scraper

Automates searching [iq.govwin.com](https://iq.govwin.com) for insurance-related government contract opportunities across SLED (State, Local, Education) entities. Results are saved to a timestamped Excel file.

---

## Requirements

- Python 3.11+
- A valid GovWin IQ account

---

## Setup

### 1. Install Python dependencies

```bash
pip install -r requirements.txt
```

### 2. Install Playwright browser

```bash
playwright install chromium
```

### 3. Configure credentials

A `.env` file is already provided in this directory. Verify it contains your credentials:

```
GOVWIN_USERNAME=your.email@example.com
GOVWIN_PASSWORD=YourPassword
```

**Never hardcode credentials in the script.** The scraper reads exclusively from `.env`.

---

## Running the Scraper

### Single run (one-time)

```bash
python govwin_scraper.py
```

The script will:
1. Log in to GovWin IQ using credentials from `.env`
2. Run a separate search for each of the 14 insurance-related keywords
3. Apply filters: SLED entity types, Pre-RFP / Active RFP stages, and target states
4. Deduplicate results across all keyword searches
5. Save everything to `govwin_results_YYYY-MM-DD.xlsx` in the same directory

### Daily scheduled run

```bash
python govwin_scraper.py --schedule
```

Runs immediately, then again every day at **06:00 AM** by default.

To specify a custom time (24-hour format):

```bash
python govwin_scraper.py --schedule --time 08:30
```

Stop the scheduler at any time with `Ctrl+C`.

---

## Output

| Column | Description |
|---|---|
| Opportunity Title | Name of the contract opportunity |
| Entity Name | Issuing government entity |
| State | State of the entity |
| Stage | Pre-RFP or Active RFP |
| Due Date | Proposal or response due date |
| Estimated Value | Contract dollar value (if listed) |
| Description | Short opportunity description |
| GovWin URL | Direct link to the opportunity |
| Date Scraped | Date the record was collected |

Output file example: `govwin_results_2026-02-26.xlsx`

---

## Search Parameters

**Keywords searched (14 total):**
- insurance broker, insurance services, commercial insurance, risk management
- property casualty, liability insurance, workers compensation
- OCIP, OSIP, owner controlled insurance program, contractor controlled insurance program
- wrap-up insurance, surety bond, employee benefits insurance

**Entity types:** All SLED — State, Local, K-12, Higher Ed, Public Entity, Special Districts, Authorities

**Stages:** Pre-RFP and Active RFP only

**States:** Georgia, South Carolina, North Carolina, Virginia, Maryland, Delaware, New Jersey, New York, Pennsylvania, Washington DC, Texas, Nevada, California, Oregon, Washington State, Florida, Louisiana

---

## Safety & Restrictions

- **Read-only:** The script only navigates search/results pages. It submits no forms, sends no messages, and takes no actions beyond scraping.
- **Credentials:** Stored only in `.env`. Never committed to source control (`.gitignore` should exclude `.env`).
- **Confirmation gate:** Any action beyond reading/scraping triggers an explicit terminal prompt requiring you to type `yes` before proceeding.
- **No internal systems:** The scraper does not access any Marsh McLennan internal systems or data.

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Login fails | Immediately prints error and exits |
| Page structure changed | Stops with a clear error message |
| Search returns no results | Logs the empty result and moves to next keyword |
| Unexpected navigation | Logs a warning and skips that keyword |

---

## Troubleshooting

**`playwright: command not found`**
```bash
python -m playwright install chromium
```

**Login fails despite correct credentials**
- Verify credentials in `.env`
- GovWin may require MFA or CAPTCHA — if so, run with `headless=False` (edit line in script) to observe the browser

**No results returned**
- GovWin's page structure may have changed
- Check the terminal log for warnings about filter sections not found
- Open GovWin manually and compare the page structure to the selectors in `govwin_scraper.py`
