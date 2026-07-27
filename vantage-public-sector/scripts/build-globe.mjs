#!/usr/bin/env node
/*
 * VANTAGE Public Sector Edition: globe coastline generation.
 *
 * Emits data/world-land.json from the world-atlas TopoJSON land-110m
 * (Natural Earth 1:110M coastlines, WGS84 lon/lat). The runtime globe
 * projects these with a plain orthographic projection.
 *
 * Regenerate:
 *   npm install --no-save world-atlas topojson-client
 *   node scripts/build-globe.mjs
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as topojson from 'topojson-client';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const world = JSON.parse(fs.readFileSync(path.join(ROOT, 'node_modules', 'world-atlas', 'land-110m.json'), 'utf8'));

const land = topojson.feature(world, world.objects.land);
const geom = land.type === 'FeatureCollection' ? land.features[0].geometry : land.geometry;

const r2 = (n) => Math.round(n * 100) / 100;
const polys = (geom.type === 'Polygon' ? [geom.coordinates] : geom.coordinates)
  .map((poly) => poly.map((ring) => ring.map(([lng, lat]) => [r2(lng), r2(lat)])));

const out = {
  source: 'world_atlas',
  note: 'Natural Earth 1:110M land polygons via the world-atlas npm package, lon/lat WGS84, rounded to 2 decimals.',
  polygons: polys
};

const outPath = path.join(ROOT, 'data', 'world-land.json');
fs.writeFileSync(outPath, JSON.stringify(out) + '\n');
const kb = Math.round(fs.statSync(outPath).size / 1024);
let points = 0;
for (const poly of polys) for (const ring of poly) points += ring.length;
console.log('data/world-land.json written (' + kb + ' KB, ' + polys.length + ' polygons, ' + points + ' points)');
