# VANTAGE Public Sector Edition

Internal prospecting and property intelligence tool for the Marsh **Public Entity and Education** practice (Marsh Industry Operations, Business Intelligence Group).

The repo exists for maintainability. The deliverable is a single self-contained HTML file:

```
dist/VANTAGE_PublicSector.html
```

## Quick start

```bash
npm run dev        # local dev server on :8080 (modules + JSON loaded separately)
npm run validate   # data schema, coverage and provenance checks (also runs in CI)
npm run build      # single-file bundle, three.js via pinned r128 CDN tag
npm run build:vendor  # single-file bundle with three.js r128 inlined (CDN-proof)
npm run test       # validate + vendored build
node test/verify.js   # headless browser verification, including a WebGL-disabled pass
```

`npm run build` refuses to bundle if data validation fails. The committed `dist/` artifact is the vendored build, so it works even where Marsh blocks the CDN.

## Access

- `5596` admin: sees every account
- `1905` producer: pick your name from the roster, confirm with your last name, see only your book

## Layout

```
index.html            dev entry point, loads modules and data files
build.js              bundles everything into dist/ as one file (--vendor inlines three.js)
src/                  app modules on a shared V namespace (no bundler required)
  state.js            central state, shell, KPI strip
  auth.js             access codes and producer confirmation
  scope.js            role scoping, filters, POOL_BPS premium pool math
  map-cartogram.js    squarified treemap, tile area = state nominal GDP, BEA regions
  map-geo.js          Albers equal-area conic, AK/HI insets, TIV-scaled markers
  viewer-3d.js        three.js massing (one band per floor) + SVG fallback + empty state
  drawer.js           entity panel: Property / Opportunity / Generate + Sources
  lenore.js           Lenore generation panel with offline fallback
  views/              map, segments, pipeline, verification
styles/               tokens.css (Marsh palette, locked) and vantage.css
data/                 all datasets, one JSON per entity segment plus sources.json
scripts/
  validate-data.js    fails CI on any provenance, coverage or em dash violation
  build-entities.js   optional helper that assembles data/entities/*.json
vendor/               three.js r128 exactly as published on npm (three@0.128.0)
test/verify.js        Playwright pass with WebGL on, plus a pass with WebGL disabled
dist/                 the shipping artifact
```

## Data and provenance

136 entities across all 50 states plus DC, seven segments (Cities and Municipalities, Transit Authorities, Water and Wastewater, Higher Education, Public Health Systems, Federal and GovCon, Airports and Aviation). Coverage rules enforced by `scripts/validate-data.js`:

- every state and DC has at least one entity
- every state above 500B nominal GDP has at least 3
- the 10 largest states by GDP have at least 5
- every segment has at least 12; no segment exceeds 30 percent of the total

Every field of every entity carries a provenance tag:

- `public`: from a named dataset recorded in `data/sources.json` (FAA NPIAS and enplanements, FTA NTD, IPEDS, CMS POS, Census ASPEP, EPA SDWIS, GSA IOLP, OpenStreetMap, BEA)
- `derived`: computed from public inputs; the formula travels with the record and shows in the UI
- `modeled`: synthetic placeholder (incumbent broker, renewal date, trigger); rendered with a persistent MODELED badge and covered by the gold demonstration banner

If a public value could not be found the field is `null`, never invented. A null floor count is not a gap, it is the product: the entity gets `no-record` status, sorts to the top of the Verification Queue, drives the "Structures With No Floor Record" KPI, and the massing viewer shows an explicit empty state instead of a guessed building.

### Known limitations of this data compile

Read this before treating any record as research:

1. **Compiled offline.** The build environment's network policy blocked live retrieval of every upstream dataset, including the Overpass API for OpenStreetMap. Records were compiled on 2026-07-26 from the most recent published editions of the named registries as known to the compiling model, and rounded. They are registry-consistent approximations, not fresh pulls. Re-verify against the live dataset before client use; `data/sources.json` carries the same warning.
2. **Building attributes are mostly null on purpose.** `floors` is set for only 12 structures whose counts are widely documented; `height`, `constr` and `roof` are null everywhere; `sqft` is public only for the federal segment (GSA IOLP). That is the no-invention rule doing its job, and it is what feeds the Verification Queue.
3. **Coordinates** are registry-grade approximations (3 to 4 decimals) of the named site, good enough for the map and the keyless Google deep links, not for parcel work.

## Hard rules honored here

- No em dashes anywhere: code, comments, data, README, UI copy. Validation fails on one.
- Marsh palette only, plus the seven segment accents in `data/segments.json`.
- No API keys anywhere. Google Maps, Street View and Google Earth links are keyless deep links.
- three.js is pinned at r128 and vendored from the npm `three@0.128.0` package; the app works with the CDN blocked (SVG elevation fallback) and with WebGL disabled (verified in `test/verify.js`, not assumed).
- The Marsh internal AI portal is named Lenore.
- The practice name is Public Entity and Education.
