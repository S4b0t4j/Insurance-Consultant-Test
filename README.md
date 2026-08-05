# VANTAGE Public Sector

Public sector risk intelligence: a Flutter web dashboard that monitors
federal, state and local developments, plus three tools:

- **Risk Desk** — type one emerging risk (e.g. "helium supply shortage") and a
  staged swarm of Claude agents researches it with live web search, then
  underwriter / broker / risk-manager specialist lenses produce a
  practitioner-grade brief of the commercial insurance implications, with
  citations. One click turns the brief into a formatted report.
- **Report Studio** — upload a document as a *template* (.pptx or .docx, e.g.
  the public-entity risk report deck) plus supporting sources (live news
  topics, PDFs, Word/PowerPoint files, thought leadership), and generate a new
  edition:
  - **Clone mode**: your file is reused byte-for-byte — backgrounds, images
    and charts untouched — with the text rewritten by Claude to match the new
    edition, reviewable block-by-block before download.
  - **Rebuild mode**: a fresh deck/document is generated from nine slide
    archetypes, styled with the colors and fonts extracted from your template.

- **Entity Map** — the VANTAGE entity map (`vantage-public-sector/`), a
  self-contained HTML/JS app covering 136 provenance-tagged public entities
  across all 51 states with a 3D globe, cartogram and per-entity drawer. It
  builds to a single file that the dashboard serves as a static asset and
  frames in-place, so it stays independently buildable and testable.

Risk Desk and Report Studio are hidden behind per-user access grants (Admin → Users) and all
activity is recorded in Admin → Audit Log. **Read `docs/DEPLOYMENT.md` before
deploying — this feature must be hosted privately (Cloudflare Pages + Access),
not on public GitHub Pages.** For the click-by-click hosting walkthrough, see
`docs/CLOUDFLARE_SETUP.md`.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

`tool/verify_template.dart` sanity-checks the OOXML engine against any real
.pptx: `dart run tool/verify_template.dart <template.pptx> <output-dir>`.

### Entity Map

The map is a separate vanilla-JS app with its own build and browser tests:

```bash
cd vantage-public-sector
npm run validate          # dataset integrity
node build.js --vendor    # single-file build, three.js inlined
node test/verify.js       # browser checks (needs playwright)
```

`--vendor` matters: the default build links three.js from a CDN, which fails
on networks that block them. After rebuilding, copy the output over
`web/vantage-map.html` — that is the copy the dashboard serves.

Default admin login (change immediately): `admin@vantage.local` / `vantage2026`.
