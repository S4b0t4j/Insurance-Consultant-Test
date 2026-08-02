# Deployment & Access Control — Report Studio / Risk Desk

Report Studio and Risk Desk must **not** be publicly visible online, and access
must be monitored. This document is the authoritative guidance for hosting the
app privately.

## TL;DR

1. **Do not deploy this feature through the public GitHub Pages workflow.**
2. Host on **Cloudflare Pages** and put **Cloudflare Access** (Zero Trust) in
   front of it. Access gives you a server-enforced login (email allowlist or
   your IdP/SSO) **and per-user access logs** — that is the real "who has
   access" monitor.
3. Inside the app, admins grant Report Studio access per user (default deny)
   and can review the advisory audit log under **Admin → Audit Log**.

## 1. GitHub Pages is public — keep this feature off it

`.github/workflows/deploy.yml` publishes `main` (and one legacy branch) to
**public** GitHub Pages at `/Insurance-Consultant-Test/`. Anyone with the URL
can load the app. The in-app login is client-side JavaScript and is
**advisory only** — it cannot withstand a motivated visitor.

- Never add `claude/document-template-dashboard-*` to that workflow's
  branch triggers.
- Before merging this feature to `main`, either disable the Pages workflow or
  complete the Cloudflare setup below and remove the Pages deployment
  (repo **Settings → Pages → Disable**).

## 2. Private hosting: Cloudflare Pages + Cloudflare Access

The repo already contains `wrangler.toml` configured for Cloudflare Pages
(`pages_build_output_dir = "build/web"`).

1. **Create the Pages project** (Cloudflare dashboard → Workers & Pages →
   Create → Pages → connect this repository).
   - Build command: `flutter build web --release`
   - Build output: `build/web`
   - Do **not** set a `--base-href`; Pages serves at the domain root.
2. **Protect it with Cloudflare Access** (Zero Trust → Access → Applications
   → Add an application → Self-hosted):
   - Application domain: your `*.pages.dev` domain (cover the whole site
     with path `*`).
   - Policy: *Allow* → Include → **Emails** (list each authorized person) or
     your identity provider (Azure AD/Okta/Google Workspace) for SSO.
   - Session duration: 24 hours is a sensible default.
3. **Monitoring who has access / who got in**: Zero Trust → Logs → Access.
   Every authentication attempt (allowed and blocked) is logged with email,
   IP, time and application. This is the authoritative access log.
4. Optional hardening: add a *Block everyone else* catch-all policy, enable
   WARP/device posture checks, and restrict to your country.

Cloudflare Access sits in front of every request, so even the static assets
are unreachable without authenticating. This is what actually satisfies
"shielded from online visibility".

## 3. In-app access control (second layer)

- Users are managed under **Admin → Users**. New users default to **no**
  Report Studio/Risk Desk access; an admin flips the per-user
  "Report Studio & Risk Desk access" switch. Admins have access implicitly.
- Grants and revocations, logins/failed logins, template uploads, source
  uploads, generations, downloads and risk analyses are recorded in
  **Admin → Audit Log** (exportable as JSON).
- **Honest limitation:** this log lives in browser storage on each user's
  machine and can be cleared by that user. Treat it as workflow
  accountability, not forensics — the Cloudflare Access log is the record.

## 4. Claude API key

The Claude API key is entered under **Admin → Claude API** and stored in the
browser's local storage (existing app pattern). Because Cloudflare Access
limits who can reach the app at all, this is acceptable — but still:

- use a **dedicated key** for this app,
- set a **monthly spend limit** on it in the Anthropic console,
- rotate it if a device is lost.

Risk Desk uses Anthropic's server-side **web search** tool for live research.
If web search is not enabled for your organization, Risk Desk automatically
degrades to feed/upload-grounded research and says so in the UI.

## 5. Local/offline use

For maximum shielding you can skip hosting entirely and run locally:

```bash
flutter run -d chrome            # dev
flutter build web --release      # then serve build/web on an internal host
```
