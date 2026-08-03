# Cloudflare Setup — click-by-click

This gets the app hosted **privately**: Cloudflare Pages builds it from GitHub,
and Cloudflare Access puts a server-enforced login in front so only people on
your allowlist can even load the page. Total time: ~20 minutes. You need a
free Cloudflare account (https://dash.cloudflare.com/sign-up).

> ⚠️ **Order matters.** Between the first deploy (step 1) and enabling Access
> (step 2) the site is publicly reachable at its `*.pages.dev` URL. Do the
> Access step immediately after the first deploy, **before** sharing the URL
> and **before** entering your Claude API key in the app.

## Step 1 — Create the Pages project

1. Cloudflare dashboard → **Workers & Pages** → **Create** → **Pages** →
   **Connect to Git**.
2. Authorize Cloudflare's GitHub app and select the
   `S4b0t4j/Insurance-Consultant-Test` repository.
3. Configure the build:
   - **Production branch**: `claude/document-template-dashboard-mxc1vx`
     (switch this to `main` later, after PR #10 merges).
   - **Build command**: `bash cloudflare-build.sh`
   - **Build output directory**: `build/web`
   - Leave root directory and environment variables empty.
4. Click **Save and Deploy**. The first build takes ~5–10 minutes (it
   bootstraps the Flutter SDK); later builds are similar unless you enable
   build caching. When it finishes you get a URL like
   `https://<project>.pages.dev`.
5. **Don't open/share the URL yet** — go straight to Step 2.

## Step 2 — Lock it down with Cloudflare Access

1. Dashboard → **Zero Trust** (left sidebar). First time in, pick any team
   name and the **Free** plan.
2. **Access** → **Applications** → **Add an application** → **Self-hosted**.
3. Application configuration:
   - **Application name**: e.g. `Risk Report Studio`
   - **Session duration**: `24 hours`
   - **Application domain**: select your `<project>.pages.dev` domain,
     **Path**: leave empty (covers everything).
4. **Add a policy**:
   - **Policy name**: `Allowed users` · **Action**: `Allow`
   - **Include** → **Emails** → list every person who should have access
     (you can use `Emails ending in` for a whole company domain, or connect
     Azure AD/Okta/Google Workspace under Settings → Authentication for SSO).
5. Save the application. From now on, opening the URL shows Cloudflare's
   login (email one-time PIN by default); anyone not on the list is blocked
   before the app ever loads.
6. Optional hardening: add a second policy `Action: Block` / `Everyone` below
   the Allow policy; restrict countries; require device posture.

**Also cover preview deployments:** Pages creates
`<hash>.<project>.pages.dev` URLs for non-production branches. In the Access
application, add a second domain entry `*.<project>.pages.dev` so previews are
protected too — or disable preview deployments in the Pages project settings.

## Step 3 — Monitor who has access

- **Who is allowed**: Zero Trust → Access → Applications → your app →
  Policies (the email list is the source of truth; edit any time).
- **Who actually got in (or was blocked)**: Zero Trust → **Logs** →
  **Access**. Every authentication attempt is recorded with email, IP, time,
  and allow/block outcome. This is the authoritative access log; the in-app
  Admin → Audit Log is a convenience layer on top.

## Step 4 — First login in the app

1. Open `https://<project>.pages.dev`, pass the Cloudflare login.
2. Sign in with the seeded admin `admin@vantage.local` / `vantage2026` and
   **change it** (Admin → Users: create your own admin account, then remove
   or deactivate the seed).
3. Admin → **Claude API**: paste your Anthropic API key. Use a dedicated key
   with a monthly spend cap (console.anthropic.com → Billing → Limits). For
   the Risk Desk to use live web search, the key's organization must have
   web search enabled; without it the swarm degrades gracefully.
4. Admin → **Users**: add your teammates and flip on "Report Studio & Risk
   Desk access" for those who should see the new tools.

## Ongoing

- **Deploys**: every push to the production branch redeploys automatically.
  After PR #10 merges, change the production branch to `main`
  (Pages project → Settings → Builds & deployments) **and disable the old
  public GitHub Pages workflow** (repo Settings → Pages → Disable, and/or
  delete `.github/workflows/deploy.yml`) so the app never ships to a public
  URL.
- **Adding/removing people**: edit the Access policy email list — takes
  effect immediately; active sessions expire within the session duration.
- **Custom domain** (optional): Pages project → Custom domains. If you add
  one, also add it to the Access application's domain list.
