#!/usr/bin/env node
/*
 * VANTAGE Public Sector Edition: single-file build.
 *
 * Produces dist/VANTAGE_PublicSector.html with zero external file
 * dependencies: all CSS, all JS modules, and all data inlined.
 *
 * Usage:
 *   node build.js            three.js loads from the pinned r128 CDN tag
 *   node build.js --vendor   three.js r128 is inlined from vendor/, so the
 *                            bundle works where Marsh blocks the CDN
 *
 * Data validation runs first and a failed validation fails the build.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = __dirname;
const read = (p) => fs.readFileSync(path.join(ROOT, p), 'utf8');

const vendorFlag = process.argv.includes('--vendor');

/* 1. validate data first; refuse to bundle bad data */
execFileSync(process.execPath, [path.join(ROOT, 'scripts', 'validate-data.js')], { stdio: 'inherit' });

/* 2. collect the pieces */
const css = [
  read('styles/tokens.css'),
  read('styles/vantage.css')
].join('\n');

const JS_ORDER = [
  'src/state.js',
  'src/auth.js',
  'src/scope.js',
  'src/map-cartogram.js',
  'src/map-geo.js',
  'src/viewer-3d.js',
  'src/drawer.js',
  'src/lenore.js',
  'src/views/map.js',
  'src/views/segments.js',
  'src/views/pipeline.js',
  'src/views/verification.js'
];
const appJs = JS_ORDER.map((f) => '/* ==== ' + f + ' ==== */\n' + read(f)).join('\n');

const data = {
  gdp: JSON.parse(read('data/gdp-by-state.json')),
  segments: JSON.parse(read('data/segments.json')),
  producers: JSON.parse(read('data/producers.json')),
  sources: JSON.parse(read('data/sources.json')),
  entities: []
};
for (const seg of ['city', 'transit', 'water', 'highered', 'health', 'fed', 'air']) {
  data.entities = data.entities.concat(JSON.parse(read('data/entities/' + seg + '.json')));
}

/* 3. assemble from the dev entry so markup never drifts between dev and dist */
let html = read('index.html');

/* replace() takes functions everywhere below: a plain replacement string
   would mangle output wherever the payload contains $-patterns. */
html = html.replace(/<link rel="stylesheet" href="styles\/tokens.css">\s*<link rel="stylesheet" href="styles\/vantage.css">/,
  () => '<style>\n' + css + '\n</style>');

if (vendorFlag) {
  const three = read('vendor/three.r128.min.js');
  html = html.replace(/<script src="https:\/\/cdnjs\.cloudflare\.com\/ajax\/libs\/three\.js\/r128\/three\.min\.js"><\/script>/,
    () => '<script>\n' + three + '\n</script>');
}

const scriptTags = JS_ORDER.map((f) => '<script src="' + f + '"></script>').join('\n');
const dataScript = '<script>window.VANTAGE_DATA = ' + JSON.stringify(data) + ';</script>';
html = html.replace(scriptTags, () => dataScript + '\n<script>\n' + appJs + '\n</script>');

if (html.includes('src="src/')) {
  console.error('Build error: some module script tags were not inlined.');
  process.exit(1);
}
if (html.includes('\u2014')) {
  console.error('Build error: em dash found in bundle output.');
  process.exit(1);
}

/* 4. write */
fs.mkdirSync(path.join(ROOT, 'dist'), { recursive: true });
const out = path.join(ROOT, 'dist', 'VANTAGE_PublicSector.html');
fs.writeFileSync(out, html);
const kb = Math.round(fs.statSync(out).size / 1024);
console.log('Built dist/VANTAGE_PublicSector.html (' + kb + ' KB, three.js ' + (vendorFlag ? 'vendored inline' : 'via pinned CDN tag') + ')');
