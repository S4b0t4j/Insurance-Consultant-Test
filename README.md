# Insurance-Consultant-Test

Flutter web dashboard for Marsh Education Practice, extended with two
access-controlled tools:

- **Risk Desk** — type one emerging risk (e.g. "helium supply shortage") and a
  staged swarm of Claude agents researches it with live web search, then
  underwriter / broker / risk-manager specialist lenses produce a
  practitioner-grade brief of the commercial insurance implications, with
  citations. One click turns the brief into a formatted report.
- **Report Studio** — upload a document as a *template* (.pptx or .docx, e.g.
  the Marsh public-entity risk report deck) plus supporting sources (live news
  topics, PDFs, Word/PowerPoint files, thought leadership), and generate a new
  edition:
  - **Clone mode**: your file is reused byte-for-byte — backgrounds, images
    and charts untouched — with the text rewritten by Claude to match the new
    edition, reviewable block-by-block before download.
  - **Rebuild mode**: a fresh deck/document is generated from nine slide
    archetypes, styled with the colors and fonts extracted from your template.

Both tools are hidden behind per-user access grants (Admin → Users) and all
activity is recorded in Admin → Audit Log. **Read `docs/DEPLOYMENT.md` before
deploying — this feature must be hosted privately (Cloudflare Pages + Access),
not on public GitHub Pages.**

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

`tool/verify_template.dart` sanity-checks the OOXML engine against any real
.pptx: `dart run tool/verify_template.dart <template.pptx> <output-dir>`.

Default admin login (change immediately): `admin@marsh.com` / `marsh2026`.
