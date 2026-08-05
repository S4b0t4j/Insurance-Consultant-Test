#!/usr/bin/env node
/*
 * VANTAGE Public Sector Edition: geographic base map generation.
 *
 * Emits data/us-borders.json from the US Atlas TopoJSON (Census Bureau
 * cartographic boundaries, pre-projected with the standard d3
 * geoAlbersUsa composite: scale 1300, translate 487.5,305, frame
 * 975x610). Entity coordinates are projected with the same projection at
 * generation time, so the runtime needs no projection code and markers
 * align with the drawn borders exactly.
 *
 * Regenerate after adding entities:
 *   npm install --no-save us-atlas topojson-client d3-geo
 *   node scripts/build-geo.mjs
 * Validation fails if an entity has no projected point here.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as topojson from 'topojson-client';
import { geoAlbersUsa } from 'd3-geo';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const us = JSON.parse(fs.readFileSync(path.join(ROOT, 'node_modules', 'us-atlas', 'states-albers-10m.json'), 'utf8'));

const r1 = (n) => Math.round(n * 10) / 10;

/* Serialize planar GeoJSON to SVG path data with 0.1px rounding. */
function ring(coords) {
  return 'M' + coords.map((p) => r1(p[0]) + ',' + r1(p[1])).join('L') + 'Z';
}
function line(coords) {
  return 'M' + coords.map((p) => r1(p[0]) + ',' + r1(p[1])).join('L');
}
function toPath(geom) {
  if (geom.type === 'Polygon') return geom.coordinates.map(ring).join('');
  if (geom.type === 'MultiPolygon') return geom.coordinates.map((poly) => poly.map(ring).join('')).join('');
  if (geom.type === 'LineString') return line(geom.coordinates);
  if (geom.type === 'MultiLineString') return geom.coordinates.map(line).join('');
  throw new Error('Unhandled geometry ' + geom.type);
}

const nation = topojson.feature(us, us.objects.nation);
const interiorBorders = topojson.mesh(us, us.objects.states, (a, b) => a !== b);

/* State code lookup for centroid labels. */
const NAME_TO_CODE = {
  Alabama: 'AL', Alaska: 'AK', Arizona: 'AZ', Arkansas: 'AR', California: 'CA',
  Colorado: 'CO', Connecticut: 'CT', Delaware: 'DE', 'District of Columbia': 'DC', Florida: 'FL',
  Georgia: 'GA', Hawaii: 'HI', Idaho: 'ID', Illinois: 'IL', Indiana: 'IN',
  Iowa: 'IA', Kansas: 'KS', Kentucky: 'KY', Louisiana: 'LA', Maine: 'ME',
  Maryland: 'MD', Massachusetts: 'MA', Michigan: 'MI', Minnesota: 'MN', Mississippi: 'MS',
  Missouri: 'MO', Montana: 'MT', Nebraska: 'NE', Nevada: 'NV', 'New Hampshire': 'NH',
  'New Jersey': 'NJ', 'New Mexico': 'NM', 'New York': 'NY', 'North Carolina': 'NC', 'North Dakota': 'ND',
  Ohio: 'OH', Oklahoma: 'OK', Oregon: 'OR', Pennsylvania: 'PA', 'Rhode Island': 'RI',
  'South Carolina': 'SC', 'South Dakota': 'SD', Tennessee: 'TN', Texas: 'TX', Utah: 'UT',
  Vermont: 'VT', Virginia: 'VA', Washington: 'WA', 'West Virginia': 'WV', Wisconsin: 'WI', Wyoming: 'WY'
};

/* Planar centroid per state (area-weighted over the largest polygon ring
   is overkill for labels; a bbox center of the largest ring is stable). */
function largestRingCenter(geom) {
  let best = null, bestArea = -1;
  const polys = geom.type === 'Polygon' ? [geom.coordinates] : geom.coordinates;
  for (const poly of polys) {
    const outer = poly[0];
    let minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
    for (const [x, y] of outer) {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    const area = (maxX - minX) * (maxY - minY);
    if (area > bestArea) { bestArea = area; best = [r1((minX + maxX) / 2), r1((minY + maxY) / 2)]; }
  }
  return best;
}

const labels = {};
for (const f of topojson.feature(us, us.objects.states).features) {
  const code = NAME_TO_CODE[f.properties.name];
  if (code) labels[code] = largestRingCenter(f.geometry);
}

/* Project every entity with the same projection the atlas was built with. */
const projection = geoAlbersUsa().scale(1300).translate([487.5, 305]);
const points = {};
const segFiles = ['city', 'transit', 'water', 'highered', 'health', 'fed', 'air'];
for (const seg of segFiles) {
  const list = JSON.parse(fs.readFileSync(path.join(ROOT, 'data', 'entities', seg + '.json'), 'utf8'));
  for (const e of list) {
    const p = projection([e.lng, e.lat]);
    if (!p) throw new Error(e.id + ': coordinates fall outside the AlbersUsa composite');
    points[e.id] = [r1(p[0]), r1(p[1])];
  }
}

const out = {
  source: 'us_atlas',
  projection: 'd3 geoAlbersUsa, scale 1300, translate [487.5, 305]',
  viewBox: '0 0 975 610',
  nation: toPath(nation.type === 'FeatureCollection' ? nation.features[0].geometry : nation.geometry),
  states: toPath(interiorBorders),
  labels: labels,
  points: points
};

const outPath = path.join(ROOT, 'data', 'us-borders.json');
fs.writeFileSync(outPath, JSON.stringify(out) + '\n');
const kb = Math.round(fs.statSync(outPath).size / 1024);
console.log('data/us-borders.json written (' + kb + ' KB, ' + Object.keys(points).length + ' entity points, ' + Object.keys(labels).length + ' state labels)');
