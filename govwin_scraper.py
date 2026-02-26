#!/usr/bin/env python3
"""
GovWin IQ Opportunity Scraper
Scrapes government contract opportunities from iq.govwin.com for insurance-related keywords.
Credentials are read exclusively from .env — never hardcoded.

Usage:
    python govwin_scraper.py
    python govwin_scraper.py --schedule          # Run daily at 06:00
    python govwin_scraper.py --schedule --time 08:30  # Run daily at 08:30
"""

import argparse
import logging
import os
import sys
import time
from datetime import date, datetime
from pathlib import Path

from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Dependency guard — fail fast with helpful message
# ---------------------------------------------------------------------------
try:
    from playwright.sync_api import sync_playwright, TimeoutError as PWTimeoutError
except ImportError:
    print("ERROR: playwright is not installed. Run: pip install -r requirements.txt && playwright install chromium")
    sys.exit(1)

try:
    import openpyxl
    from openpyxl.styles import Font, PatternFill, Alignment
except ImportError:
    print("ERROR: openpyxl is not installed. Run: pip install -r requirements.txt")
    sys.exit(1)

try:
    import schedule
except ImportError:
    print("ERROR: schedule is not installed. Run: pip install -r requirements.txt")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("govwin_scraper")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
GOVWIN_BASE_URL = "https://iq.govwin.com"
LOGIN_URL = f"{GOVWIN_BASE_URL}/neo/login"
SEARCH_URL = f"{GOVWIN_BASE_URL}/neo/opportunity/search"

KEYWORDS = [
    "insurance broker",
    "insurance services",
    "commercial insurance",
    "risk management",
    "property casualty",
    "liability insurance",
    "workers compensation",
    "OCIP",
    "OSIP",
    "owner controlled insurance program",
    "contractor controlled insurance program",
    "wrap-up insurance",
    "surety bond",
    "employee benefits insurance",
]

# SLED entity types to include
SLED_ENTITY_TYPES = [
    "State",
    "Local",
    "K-12",
    "Higher Ed",
    "Public Entity",
    "Special Districts",
    "Authorities",
]

# Opportunity stages
STAGES = ["Pre-RFP", "Active RFP"]

# Target states
TARGET_STATES = [
    "Georgia",
    "South Carolina",
    "North Carolina",
    "Virginia",
    "Maryland",
    "Delaware",
    "New Jersey",
    "New York",
    "Pennsylvania",
    "Washington DC",
    "Texas",
    "Nevada",
    "California",
    "Oregon",
    "Washington",
    "Florida",
    "Louisiana",
]

# Excel column headers
COLUMNS = [
    "Opportunity Title",
    "Entity Name",
    "State",
    "Stage",
    "Due Date",
    "Estimated Value",
    "Description",
    "GovWin URL",
    "Date Scraped",
]

# ---------------------------------------------------------------------------
# Credential loading
# ---------------------------------------------------------------------------

def load_credentials() -> tuple[str, str]:
    """Load credentials from .env — never from hardcoded values."""
    env_path = Path(__file__).parent / ".env"
    if not env_path.exists():
        log.error(".env file not found at %s", env_path)
        log.error("Create a .env file with GOVWIN_USERNAME and GOVWIN_PASSWORD.")
        sys.exit(1)

    load_dotenv(dotenv_path=env_path, override=True)
    username = os.getenv("GOVWIN_USERNAME", "").strip()
    password = os.getenv("GOVWIN_PASSWORD", "").strip()

    if not username or not password:
        log.error("GOVWIN_USERNAME or GOVWIN_PASSWORD is missing in .env")
        sys.exit(1)

    log.info("Credentials loaded from .env (username: %s)", username)
    return username, password


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------

def login(page, username: str, password: str) -> None:
    """Log in to GovWin IQ. Raises SystemExit on failure."""
    log.info("Navigating to login page: %s", LOGIN_URL)
    page.goto(LOGIN_URL, wait_until="networkidle", timeout=60_000)

    log.info("Entering username...")
    username_field = page.locator("input[type='email'], input[name*='user'], input[id*='user'], input[placeholder*='email' i], input[placeholder*='user' i]").first
    username_field.fill(username)

    log.info("Entering password...")
    password_field = page.locator("input[type='password']").first
    password_field.fill(password)

    log.info("Submitting login form...")
    # Click the login/sign-in button
    submit_btn = page.locator(
        "button[type='submit'], input[type='submit'], button:has-text('Sign In'), button:has-text('Log In'), button:has-text('Login')"
    ).first
    submit_btn.click()

    # Wait for navigation / dashboard to confirm login success
    try:
        page.wait_for_url("**/neo/**", timeout=30_000)
    except PWTimeoutError:
        pass

    # Confirm we're NOT still on the login page
    if "/login" in page.url or "/signin" in page.url.lower():
        log.error("Login FAILED — still on login page. Check credentials in .env.")
        log.error("Current URL: %s", page.url)
        sys.exit(1)

    log.info("Login successful. Current URL: %s", page.url)


# ---------------------------------------------------------------------------
# Search helpers
# ---------------------------------------------------------------------------

def build_search_url(keyword: str) -> str:
    """
    Return the GovWin search URL for a keyword.
    Filters are applied interactively on the page; this provides the base search.
    """
    from urllib.parse import urlencode, quote_plus
    params = {
        "keyword": keyword,
    }
    return f"{SEARCH_URL}?{urlencode(params)}"


def safe_text(locator) -> str:
    """Return text content of a locator or empty string if not found."""
    try:
        return locator.inner_text(timeout=3_000).strip()
    except Exception:
        return ""


def safe_attr(locator, attr: str) -> str:
    """Return an attribute of a locator or empty string if not found."""
    try:
        val = locator.get_attribute(attr, timeout=3_000)
        return (val or "").strip()
    except Exception:
        return ""


# ---------------------------------------------------------------------------
# Filter application
# ---------------------------------------------------------------------------

def apply_filters(page) -> None:
    """
    Apply SLED entity type, stage, and state filters on the GovWin search page.
    This function is tolerant of UI variations — if a filter panel is not
    found it logs a warning rather than crashing, so the caller can decide
    whether to abort.
    """
    log.info("Applying search filters (SLED entity types, stages, states)...")

    # GovWin uses a faceted-search sidebar. We attempt to interact with it.
    # The exact selectors may need adjustment if GovWin updates its UI.
    # If any filter section is not found we log a warning.

    _apply_filter_section(page, "Stage", STAGES)
    _apply_filter_section(page, "Entity Type", SLED_ENTITY_TYPES)
    _apply_filter_section(page, "State", TARGET_STATES)

    log.info("Filters applied. Waiting for results to refresh...")
    page.wait_for_load_state("networkidle", timeout=30_000)


def _apply_filter_section(page, section_name: str, values: list[str]) -> None:
    """
    Attempt to find a filter section by heading text and check each value.
    Logs a warning if the section is not found — caller decides whether to abort.
    """
    try:
        # Try to find and expand the filter section
        section_header = page.locator(
            f"text='{section_name}'"
        ).first
        if section_header.count() == 0:
            log.warning("Filter section '%s' not found on page — skipping.", section_name)
            return

        # Expand if collapsed
        try:
            section_header.click(timeout=3_000)
            page.wait_for_timeout(500)
        except Exception:
            pass

        # Check each value checkbox / filter item
        for value in values:
            try:
                checkbox = page.locator(
                    f"label:has-text('{value}') input[type='checkbox'], "
                    f"span:has-text('{value}'), "
                    f"a:has-text('{value}')"
                ).first
                if checkbox.is_visible(timeout=2_000):
                    if not checkbox.is_checked():
                        checkbox.click(timeout=2_000)
                        page.wait_for_timeout(300)
            except Exception:
                pass  # Individual filter value not found; continue

    except Exception as exc:
        log.warning("Could not apply '%s' filter: %s", section_name, exc)


# ---------------------------------------------------------------------------
# Result extraction
# ---------------------------------------------------------------------------

def extract_results(page, keyword: str) -> list[dict]:
    """
    Extract all opportunity rows from the current search results page,
    iterating through pagination.
    """
    results: list[dict] = []
    page_num = 1
    today_str = date.today().isoformat()

    while True:
        log.info("  Extracting page %d of results...", page_num)

        # Wait for result rows to appear
        try:
            page.wait_for_selector(
                "table tbody tr, .opportunity-row, .search-result-item, [class*='result']",
                timeout=15_000,
            )
        except PWTimeoutError:
            log.info("  No results found on page %d.", page_num)
            break

        rows = page.locator(
            "table tbody tr, .opportunity-row, .search-result-item"
        ).all()

        if not rows:
            log.info("  No result rows detected on page %d.", page_num)
            break

        for row in rows:
            try:
                record = _extract_row(row, today_str)
                if record:
                    results.append(record)
            except Exception as exc:
                log.debug("  Row extraction error: %s", exc)

        log.info("  Page %d: extracted %d records (running total: %d)", page_num, len(rows), len(results))

        # Pagination — look for "Next" button
        next_btn = page.locator(
            "a[aria-label='Next page'], button[aria-label='Next page'], "
            "a:has-text('Next'), button:has-text('Next'), "
            "li.next a, .pagination-next"
        ).first
        try:
            if next_btn.is_visible(timeout=2_000) and next_btn.is_enabled(timeout=2_000):
                log.info("  Navigating to page %d...", page_num + 1)
                next_btn.click()
                page.wait_for_load_state("networkidle", timeout=30_000)
                page_num += 1
            else:
                log.info("  No more pages.")
                break
        except Exception:
            log.info("  Pagination ended.")
            break

    return results


def _extract_row(row, today_str: str) -> dict | None:
    """Extract a single result row into a dict. Returns None if row is empty."""
    # Try multiple selector strategies for each field.
    # GovWin's table structure may vary; we try broad patterns.

    title_el = row.locator("a[href*='opportunity'], td:nth-child(1) a, .opp-title a, .title a").first
    title = safe_text(title_el)
    url = safe_attr(title_el, "href")

    if not title:
        # Try plain first cell text
        title = safe_text(row.locator("td:nth-child(1)").first)

    if not title:
        return None  # Skip empty rows (e.g. header rows)

    # Build absolute URL
    if url and not url.startswith("http"):
        url = GOVWIN_BASE_URL + url

    entity = safe_text(row.locator("td:nth-child(2), .entity-name, [class*='entity']").first)
    state = safe_text(row.locator("td:nth-child(3), .state, [class*='state']").first)
    stage = safe_text(row.locator("td:nth-child(4), .stage, [class*='stage']").first)
    due_date = safe_text(row.locator("td:nth-child(5), .due-date, [class*='due']").first)
    est_value = safe_text(row.locator("td:nth-child(6), .value, [class*='value']").first)
    description = safe_text(row.locator("td:nth-child(7), .description, [class*='desc']").first)

    return {
        "Opportunity Title": title,
        "Entity Name": entity,
        "State": state,
        "Stage": stage,
        "Due Date": due_date,
        "Estimated Value": est_value,
        "Description": description,
        "GovWin URL": url,
        "Date Scraped": today_str,
    }


# ---------------------------------------------------------------------------
# Excel output
# ---------------------------------------------------------------------------

def save_to_excel(records: list[dict]) -> str:
    """Save deduplicated records to a timestamped Excel file. Returns filepath."""
    filename = f"govwin_results_{date.today().isoformat()}.xlsx"
    filepath = Path(__file__).parent / filename

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "GovWin Opportunities"

    # Header styling
    header_font = Font(bold=True, color="FFFFFF")
    header_fill = PatternFill("solid", fgColor="1F4E79")
    header_align = Alignment(horizontal="center", vertical="center", wrap_text=True)

    for col_idx, col_name in enumerate(COLUMNS, start=1):
        cell = ws.cell(row=1, column=col_idx, value=col_name)
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = header_align

    # Column widths
    col_widths = {
        "Opportunity Title": 45,
        "Entity Name": 30,
        "State": 18,
        "Stage": 15,
        "Due Date": 14,
        "Estimated Value": 16,
        "Description": 50,
        "GovWin URL": 55,
        "Date Scraped": 14,
    }
    for col_idx, col_name in enumerate(COLUMNS, start=1):
        ws.column_dimensions[openpyxl.utils.get_column_letter(col_idx)].width = col_widths.get(col_name, 20)

    # Freeze header row
    ws.freeze_panes = "A2"

    # Data rows
    alt_fill = PatternFill("solid", fgColor="EBF3FB")
    for row_idx, record in enumerate(records, start=2):
        for col_idx, col_name in enumerate(COLUMNS, start=1):
            cell = ws.cell(row=row_idx, column=col_idx, value=record.get(col_name, ""))
            cell.alignment = Alignment(vertical="top", wrap_text=True)
            if row_idx % 2 == 0:
                cell.fill = alt_fill

            # Make URL clickable
            if col_name == "GovWin URL" and record.get(col_name):
                cell.hyperlink = record[col_name]
                cell.font = Font(color="0563C1", underline="single")

    ws.auto_filter.ref = ws.dimensions
    ws.row_dimensions[1].height = 30

    wb.save(filepath)
    log.info("Results saved to: %s", filepath)
    return str(filepath)


# ---------------------------------------------------------------------------
# Deduplication
# ---------------------------------------------------------------------------

def deduplicate(records: list[dict]) -> list[dict]:
    """Remove duplicate opportunities by URL, falling back to title+entity."""
    seen: set[str] = set()
    unique: list[dict] = []
    for rec in records:
        key = rec.get("GovWin URL") or f"{rec.get('Opportunity Title','')}|{rec.get('Entity Name','')}"
        if key and key not in seen:
            seen.add(key)
            unique.append(rec)
    return unique


# ---------------------------------------------------------------------------
# Stage / state filtering (post-extraction guard)
# ---------------------------------------------------------------------------

def passes_filters(record: dict) -> bool:
    """Return True if the record matches our stage and state criteria."""
    stage = record.get("Stage", "").lower()
    state = record.get("State", "")

    stage_ok = any(s.lower() in stage for s in ["pre-rfp", "pre rfp", "active rfp", "rfp"])
    state_ok = any(s.lower() in state.lower() for s in TARGET_STATES) if state else True

    return stage_ok and state_ok


# ---------------------------------------------------------------------------
# Main scrape routine
# ---------------------------------------------------------------------------

def confirm_action(action_description: str) -> bool:
    """
    For any action beyond read/scrape, prompt the user for explicit confirmation.
    Returns True only if user types 'yes'.
    """
    print(f"\n[CONFIRMATION REQUIRED] {action_description}")
    answer = input("Type 'yes' to proceed, anything else to cancel: ").strip().lower()
    return answer == "yes"


def run_scraper() -> None:
    """Execute the full scrape session."""
    log.info("=" * 70)
    log.info("GovWin IQ Opportunity Scraper — starting run")
    log.info("=" * 70)

    username, password = load_credentials()
    all_records: list[dict] = []

    with sync_playwright() as pw:
        log.info("Launching browser (Chromium, headless)...")
        browser = pw.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            )
        )
        page = context.new_page()

        # ---- Login ----
        login(page, username, password)

        # ---- Keyword searches ----
        for keyword in KEYWORDS:
            log.info("-" * 60)
            log.info("Searching keyword: '%s'", keyword)

            try:
                search_url = build_search_url(keyword)
                log.info("Navigating to search URL: %s", search_url)
                page.goto(search_url, wait_until="networkidle", timeout=60_000)

                # Confirm we haven't drifted to an unexpected page
                current = page.url
                if not any(allowed in current for allowed in ["/neo/opportunity", "/neo/search", "/search"]):
                    log.warning(
                        "Unexpected URL after search navigation: %s — skipping keyword '%s'",
                        current, keyword,
                    )
                    continue

                # Apply filters
                try:
                    apply_filters(page)
                except Exception as exc:
                    log.warning("Filter application issue: %s — continuing with unfiltered results.", exc)

                # Extract results
                keyword_records = extract_results(page, keyword)

                # Post-extraction filter guard
                before = len(keyword_records)
                keyword_records = [r for r in keyword_records if passes_filters(r)]
                after = len(keyword_records)
                if before != after:
                    log.info("  Post-filter: kept %d / %d records matching stage/state criteria.", after, before)

                if not keyword_records:
                    log.info("  No matching results for keyword '%s'.", keyword)
                else:
                    log.info("  Keyword '%s': %d results collected.", keyword, len(keyword_records))
                    all_records.extend(keyword_records)

            except PWTimeoutError as exc:
                log.error("Timeout during search for '%s': %s", keyword, exc)
                log.error("GovWin page structure may have changed or the site is slow. Stopping.")
                break
            except Exception as exc:
                log.error("Unexpected error during search for '%s': %s", keyword, exc)
                log.error("GovWin page structure may have changed. Stopping.")
                break

        browser.close()
        log.info("Browser closed.")

    # ---- Deduplication ----
    before_dedup = len(all_records)
    all_records = deduplicate(all_records)
    log.info(
        "Deduplication: %d total records → %d unique records",
        before_dedup, len(all_records),
    )

    # ---- Save output ----
    if all_records:
        filepath = save_to_excel(all_records)
        log.info("=" * 70)
        log.info("Scrape complete. %d opportunities saved to: %s", len(all_records), filepath)
        log.info("=" * 70)
    else:
        log.info("=" * 70)
        log.info("Scrape complete. No matching opportunities found.")
        log.info("=" * 70)


# ---------------------------------------------------------------------------
# Scheduling
# ---------------------------------------------------------------------------

def run_scheduled(run_time: str = "06:00") -> None:
    """Schedule the scraper to run daily at `run_time` (HH:MM, 24-hour)."""
    log.info("Scheduler mode: scraper will run daily at %s.", run_time)
    log.info("Press Ctrl+C to stop the scheduler.")

    schedule.every().day.at(run_time).do(run_scraper)

    # Run once immediately on startup so user can verify it works
    log.info("Running an initial scrape now...")
    run_scraper()

    while True:
        schedule.run_pending()
        time.sleep(60)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="GovWin IQ Opportunity Scraper for insurance-related keywords."
    )
    parser.add_argument(
        "--schedule",
        action="store_true",
        help="Run the scraper on a daily schedule instead of a single run.",
    )
    parser.add_argument(
        "--time",
        default="06:00",
        metavar="HH:MM",
        help="Time of day (24-hour) for the scheduled run. Default: 06:00.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.schedule:
        run_scheduled(run_time=args.time)
    else:
        run_scraper()


if __name__ == "__main__":
    main()
