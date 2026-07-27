#!/usr/bin/env node
/*
 * VANTAGE Public Sector Edition: data validation.
 * Run in CI and before every build. Exits nonzero on any failure.
 *
 * Checks:
 *  1. Every entity has a provenance object covering every provenance-required field.
 *  2. Every field tagged public carries a source key that exists in sources.json.
 *  3. Every field tagged derived carries a formula.
 *  4. inc, renew and trigger are tagged modeled.
 *  5. lat/lng inside continental US bounds unless geoOverride is AK or HI.
 *  6. Every state plus DC has at least one entity.
 *  7. Every segment has at least 12 entities and no segment exceeds 30 percent.
 *  8. At least 120 entities total.
 *  9. States above 500B nominal GDP have at least 3 entities; top 10 have at least 5.
 * 10. No em dash character anywhere in any file under data/.
 * 11. Every entity has a projected map point in data/us-borders.json
 *     (regenerate with scripts/build-geo.mjs after adding entities).
 */

'use strict';

const fs = require('fs');
const path = require('path');

const DATA_DIR = path.join(__dirname, '..', 'data');
const ENT_DIR = path.join(DATA_DIR, 'entities');

const errors = [];
const fail = (msg) => errors.push(msg);

/* ---- load ---- */
const sources = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'sources.json'), 'utf8')).sources;
const gdpFile = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'gdp-by-state.json'), 'utf8'));
const segments = JSON.parse(fs.readFileSync(path.join(DATA_DIR, 'segments.json'), 'utf8'));
const segKeys = segments.map((s) => s.key);
const metricBySeg = Object.fromEntries(segments.map((s) => [s.key, s.metricKey]));

const entities = [];
for (const seg of segKeys) {
  const file = path.join(ENT_DIR, seg + '.json');
  if (!fs.existsSync(file)) {
    fail('Missing entity file for segment ' + seg);
    continue;
  }
  for (const e of JSON.parse(fs.readFileSync(file, 'utf8'))) {
    if (e.seg !== seg) fail(e.id + ': seg mismatch, file ' + seg + ' vs record ' + e.seg);
    entities.push(e);
  }
}

/* ---- 10. em dash scan over every file in data/ ---- */
(function scanEmDash(dir) {
  for (const name of fs.readdirSync(dir)) {
    const p = path.join(dir, name);
    if (fs.statSync(p).isDirectory()) {
      scanEmDash(p);
    } else {
      const text = fs.readFileSync(p, 'utf8');
      const idx = text.indexOf('\u2014');
      if (idx !== -1) fail('Em dash found in ' + p + ' at offset ' + idx);
    }
  }
})(DATA_DIR);

/* ---- 1 to 5: per-entity checks ---- */
const BASE_FIELDS = ['name', 'city', 'state', 'lat', 'lng', 'site', 'floors', 'height', 'sqft', 'built', 'constr', 'roof', 'tiv', 'prem', 'inc', 'renew', 'trigger'];
const MODELED_FIELDS = ['inc', 'renew', 'trigger'];
const CONUS = { latMin: 24.3, latMax: 49.5, lngMin: -125.0, lngMax: -66.8 };

const ids = new Set();
for (const e of entities) {
  const tag = (m) => fail(e.id + ': ' + m);
  if (ids.has(e.id)) tag('duplicate id');
  ids.add(e.id);

  if (!e.provenance || typeof e.provenance !== 'object') {
    tag('missing provenance');
    continue;
  }
  const required = BASE_FIELDS.concat([metricBySeg[e.seg]]);
  for (const field of required) {
    const p = e.provenance[field];
    if (!p) {
      tag('no provenance entry for field ' + field);
      continue;
    }
    if (p.kind === 'public') {
      if (!p.source) tag('public field ' + field + ' has no source key');
      else if (!sources[p.source]) tag('public field ' + field + ' cites unknown source ' + p.source);
    } else if (p.kind === 'derived') {
      if (!p.formula) tag('derived field ' + field + ' has no formula');
    } else if (p.kind !== 'modeled') {
      tag('field ' + field + ' has unknown provenance kind ' + p.kind);
    }
  }
  for (const field of MODELED_FIELDS) {
    if (e.provenance[field] && e.provenance[field].kind !== 'modeled') {
      tag('field ' + field + ' must be tagged modeled');
    }
  }

  if (typeof e.lat !== 'number' || typeof e.lng !== 'number') {
    tag('lat/lng missing or not numeric');
  } else {
    const inConus = e.lat >= CONUS.latMin && e.lat <= CONUS.latMax && e.lng >= CONUS.lngMin && e.lng <= CONUS.lngMax;
    if (!inConus && e.geoOverride !== 'AK' && e.geoOverride !== 'HI') {
      tag('coordinates outside continental US bounds without an AK/HI geoOverride flag');
    }
    if (e.geoOverride && e.geoOverride !== e.state) {
      tag('geoOverride ' + e.geoOverride + ' does not match state ' + e.state);
    }
  }

  if (e.floors === null && e.verif !== 'no-record') tag('floors is null but verif is not no-record');
  if (e.floors !== null && e.verif === 'no-record') tag('verif is no-record but floors is present');
  if (!gdpFile.gdp[e.state]) tag('unknown state code ' + e.state);
}

/* ---- 6, 8: coverage ---- */
if (entities.length < 120) fail('Only ' + entities.length + ' entities; at least 120 required');

const byState = {};
for (const e of entities) byState[e.state] = (byState[e.state] || 0) + 1;
for (const st of Object.keys(gdpFile.gdp)) {
  if (!byState[st]) fail('State ' + st + ' has zero entities');
}

/* ---- 9: GDP-tier minimums ---- */
const gdpSorted = Object.entries(gdpFile.gdp).sort((a, b) => b[1] - a[1]);
const top10 = gdpSorted.slice(0, 10).map(([st]) => st);
for (const [st, gdp] of gdpSorted) {
  const n = byState[st] || 0;
  if (gdp > 500 && n < 3) fail(st + ' has ' + n + ' entities; states above 500B GDP need at least 3');
  if (top10.includes(st) && n < 5) fail(st + ' has ' + n + ' entities; top 10 GDP states need at least 5');
}

/* ---- 7: segment balance ---- */
const bySeg = {};
for (const e of entities) bySeg[e.seg] = (bySeg[e.seg] || 0) + 1;
for (const seg of segKeys) {
  const n = bySeg[seg] || 0;
  if (n < 12) fail('Segment ' + seg + ' has ' + n + ' entities; at least 12 required');
  if (n / entities.length > 0.3) fail('Segment ' + seg + ' has ' + n + ' of ' + entities.length + ' entities; exceeds the 30 percent cap');
}

/* ---- 11. projected map points cover every entity ---- */
const bordersPath = path.join(DATA_DIR, 'us-borders.json');
if (!fs.existsSync(bordersPath)) {
  fail('data/us-borders.json missing; run scripts/build-geo.mjs');
} else {
  const borders = JSON.parse(fs.readFileSync(bordersPath, 'utf8'));
  for (const e of entities) {
    if (!borders.points || !borders.points[e.id]) {
      fail(e.id + ': no projected point in us-borders.json; rerun scripts/build-geo.mjs');
    }
  }
}

/* ---- report ---- */
if (errors.length) {
  console.error('DATA VALIDATION FAILED (' + errors.length + ' problem' + (errors.length === 1 ? '' : 's') + '):');
  for (const msg of errors) console.error('  - ' + msg);
  process.exit(1);
}

console.log('Data validation passed.');
console.log('  entities: ' + entities.length);
console.log('  states covered: ' + Object.keys(byState).length + ' of ' + Object.keys(gdpFile.gdp).length);
console.log('  by segment: ' + segKeys.map((s) => s + '=' + (bySeg[s] || 0)).join(', '));
console.log('  no-record floors: ' + entities.filter((e) => e.floors === null).length);
