#!/usr/bin/env node
/*
 * VANTAGE Public Sector Edition: bundle verification.
 * Drives dist/VANTAGE_PublicSector.html in headless Chromium.
 *
 * Pass 1 (WebGL on): console cleanliness, admin and producer auth paths,
 * role scoping, both map modes, all four views, POOL_BPS edit, drawer tabs,
 * modeled badges, Lenore offline fallback, discrepancy flag flow, queue
 * ordering, 3D massing canvas.
 *
 * Pass 2 (WebGL disabled via Chromium flags): the SVG elevation fallback
 * must render for a floored entity and the explicit empty state must render
 * for a no-record entity.
 *
 * Run: node test/verify.js   (requires the playwright package; in CI use
 * the preinstalled global playwright and PLAYWRIGHT_BROWSERS_PATH)
 */

'use strict';

const path = require('path');
const { chromium } = require('playwright');

const DIST = 'file://' + path.join(__dirname, '..', 'dist', 'VANTAGE_PublicSector.html');

let failures = 0;
function check(name, cond, extra) {
  if (cond) {
    console.log('  PASS ' + name);
  } else {
    failures++;
    console.log('  FAIL ' + name + (extra ? ' :: ' + extra : ''));
  }
}

async function login(page, code) {
  await page.fill('#code-input', code);
}

async function passWebglOn() {
  console.log('Pass 1: WebGL enabled');
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const consoleErrors = [];
  page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(m.text()); });
  page.on('pageerror', (e) => consoleErrors.push(String(e)));

  await page.goto(DIST);
  await page.waitForSelector('#code-input');
  check('demo banner visible', await page.isVisible('#demo-banner'));

  /* wrong code rejected */
  await login(page, '9999');
  check('wrong code rejected', (await page.textContent('#auth-error')).includes('not recognized'));

  /* admin path */
  await login(page, '5596');
  await page.waitForSelector('#app-shell:not([hidden])');
  check('admin lands on map view', await page.isVisible('#map-canvas'));
  const adminAccounts = await page.locator('.entity-row').count();
  check('admin sees all 136 accounts', adminAccounts === 136, 'saw ' + adminAccounts);

  /* market view cartogram */
  const tiles = await page.locator('.tile').count();
  check('cartogram renders 51 state tiles', tiles === 51, 'saw ' + tiles);

  /* POOL_BPS visible and editable */
  const poolBefore = await page.textContent('#pool-out');
  await page.fill('#pool-bps', '3.6');
  await page.dispatchEvent('#pool-bps', 'change');
  await page.waitForTimeout(150);
  const poolAfter = await page.textContent('#pool-out');
  check('POOL_BPS edit changes the premium pool', poolBefore !== poolAfter, poolBefore + ' vs ' + poolAfter);
  await page.fill('#pool-bps', '1.8');
  await page.dispatchEvent('#pool-bps', 'change');
  await page.waitForTimeout(100);

  /* geographic view */
  await page.click('#mode-geo');
  await page.waitForSelector('.geo-marker');
  const markers = await page.locator('.geo-marker').count();
  check('geographic view plots all in-scope entities', markers === 136, 'saw ' + markers);
  const nationD = await page.getAttribute('.geo-nation', 'd');
  check('US nation outline rendered from Census boundaries', !!nationD && nationD.length > 10000, 'path length ' + (nationD || '').length);
  check('interior state borders rendered', !!(await page.getAttribute('.geo-states', 'd')));
  const akPos = await page.evaluate(() => {
    const m = document.querySelector('.geo-marker[data-id="air-anc"]');
    return m ? [parseFloat(m.getAttribute('cx')), parseFloat(m.getAttribute('cy'))] : null;
  });
  check('Alaska entity plots inside the Alaska inset', !!akPos && akPos[0] < 250 && akPos[1] > 450, JSON.stringify(akPos));

  /* globe view: rotation, dots, country legend spin and zoom */
  await page.click('#mode-globe');
  await page.waitForSelector('#globe-canvas');
  const dbg1 = await page.evaluate(() => window.V.globe.debug());
  check('globe shows 60+ global entity dots', dbg1.dots >= 60, 'dots ' + dbg1.dots);
  check('globe auto-rotation running', dbg1.spinning === true);
  check('every showcase city carries metro GDP', dbg1.gdpTotal > 20000, 'gdp total ' + dbg1.gdpTotal);
  const panelText = await page.textContent('#globe-cities');
  check('influence panel ranks top global entities', (await page.locator('.gcity-row').count()) === 10 && panelText.includes('metro GDP') && panelText.includes('influence est.'));
  check('top influence entity is a megacity system', dbg1.topInfluence && panelText.includes(dbg1.topInfluence), dbg1.topInfluence);
  const lng1 = dbg1.center[0];
  await page.waitForTimeout(700);
  const dbg2 = await page.evaluate(() => window.V.globe.debug());
  const drift = ((lng1 - dbg2.center[0]) + 360) % 360;
  check('globe rotates counterclockwise (center drifts west)', drift > 0.5 && drift < 30, 'drift ' + drift.toFixed(2));
  check('country legend lists 45+ countries', (await page.locator('.globe-country').count()) >= 45);
  await page.click('.globe-country[data-code="JP"]');
  await page.waitForTimeout(1700);
  const dbg3 = await page.evaluate(() => window.V.globe.debug());
  check('legend click spins to the country and zooms', dbg3.focus === 'JP' && dbg3.zoom > 1.5 && Math.abs(dbg3.center[0] - 138.3) < 2 && Math.abs(dbg3.center[1] - 36.2) < 2, JSON.stringify(dbg3));
  check('rotation paused while focused', dbg3.spinning === false);
  const jpPanel = await page.textContent('#globe-cities');
  check('focused country panel shows its cities with GDP', jpPanel.includes('Tokyo Metro') && jpPanel.includes('Osaka Metro') && jpPanel.includes('$1,800B'), jpPanel.slice(0, 120));
  await page.click('#globe-reset');
  await page.waitForTimeout(1100);
  const dbg4 = await page.evaluate(() => window.V.globe.debug());
  check('reset resumes rotation and zooms out', dbg4.spinning === true && dbg4.zoom < 1.1, JSON.stringify(dbg4));
  await page.click('#mode-geo');
  await page.waitForSelector('.geo-marker');
  check('US geographic view unchanged after globe visit', (await page.locator('.geo-marker').count()) === 136);

  /* drawer via marker click: floored entity gets 3D massing.
     dispatchEvent because a co-located federal building marker overlaps
     the Philadelphia City Hall marker at real coordinates. */
  await page.dispatchEvent('.geo-marker[data-id="city-philadelphia"]', 'click');
  await page.waitForSelector('#drawer:not([hidden])');
  await page.waitForTimeout(400);
  check('3D massing canvas renders for a floored entity', (await page.locator('#viewer-wrap canvas').count()) === 1);
  check('floors fact shows the record', (await page.textContent('.facts-grid')).includes('9'));
  const links = await page.locator('.deep-link').allTextContents();
  check('keyless deep links present', links.join(',').includes('Google Maps') && links.join(',').includes('Street View') && links.join(',').includes('Google Earth'));
  const mapsHref = await page.getAttribute('.deep-link', 'href');
  check('deep links are keyless', !mapsHref.includes('key='), mapsHref);

  /* opportunity tab: modeled badges */
  await page.click('.drawer-tab[data-tab="opportunity"]');
  const badges = await page.locator('#drawer-body .badge-modeled').count();
  check('opportunity tab flags 3 modeled fields', badges >= 3, 'saw ' + badges);

  /* sources section */
  check('sources section lists datasets', (await page.textContent('.sources-box')).includes('Annual Survey of Public Employment'));

  /* generate tab: Lenore offline fallback */
  await page.click('.drawer-tab[data-tab="generate"]');
  check('Lenore model selector present', (await page.locator('#lenore-model option').count()) === 3);
  check('offline status shown without credential', (await page.textContent('#lenore-status')).includes('Offline fallback'));
  await page.click('#lenore-generate');
  const draft = await page.textContent('#lenore-out');
  check('offline draft generated', draft.includes('Public Entity Practice') && draft.includes('Offline fallback'));

  /* discrepancy flag flow */
  await page.click('.drawer-tab[data-tab="property"]');
  await page.click('#verif-flag');
  await page.waitForSelector('#flag-form');
  await page.selectOption('#flag-field', 'floors');
  await page.fill('#flag-observed', '11 including mezzanines');
  await page.fill('#flag-note', 'Two mezzanine levels not on the schedule.');
  await page.click('#flag-submit');
  await page.waitForTimeout(200);
  check('flag stored and status chip updates', (await page.textContent('.drawer-meta')).includes('Flagged'));

  /* verification queue: flagged item present, no-record sorts first */
  await page.click('#drawer-close');
  await page.click('.nav-tab[data-view="verification"]');
  await page.waitForSelector('.data-table');
  const firstIssue = await page.textContent('.data-table tbody tr:first-child');
  check('no-record sorts above everything in the queue', firstIssue.includes('No floor record'));
  const bodyText = await page.textContent('#view-root');
  check('flagged discrepancy rolls into the queue', bodyText.includes('11 including mezzanines'));
  check('no-record KPI shows 124', bodyText.includes('124'));

  /* dashboard KPI strip */
  const kpiText = await page.textContent('#kpi-strip');
  check('KPI: Structures With No Floor Record', kpiText.includes('Structures With No Floor Record'));
  check('KPI: flagged count is 1', kpiText.includes('Flagged'));

  /* no-record entity: explicit empty state in the viewer */
  await page.click('.nav-tab[data-view="pipeline"]');
  await page.waitForSelector('tr[data-id]');
  await page.click('tr[data-id="air-atl"]');
  await page.waitForSelector('#drawer:not([hidden])');
  await page.waitForTimeout(300);
  check('no-record entity shows empty state, not a guessed massing',
    (await page.locator('.viewer-empty').count()) === 1 && (await page.locator('#viewer-wrap canvas').count()) === 0);
  check('empty state names the gap', (await page.textContent('.viewer-empty')).includes('no public floor count'));
  await page.click('#drawer-close');

  /* segments view */
  await page.click('.nav-tab[data-view="segments"]');
  const segCards = await page.locator('.seg-card').count();
  check('segments view shows 7 cards', segCards === 7, 'saw ' + segCards);
  await page.click('.seg-card[data-seg="transit"]');
  await page.waitForSelector('#seg-detail table');
  const transitRows = await page.locator('#seg-detail tbody tr').count();
  check('transit segment lists 18 accounts', transitRows === 18, 'saw ' + transitRows);

  /* logout, producer path with roster confirmation */
  await page.click('#logout-btn');
  await page.waitForSelector('#code-input');
  await login(page, '1905');
  await page.waitForSelector('.roster-btn');
  check('producer roster lists 3 producers', (await page.locator('.roster-btn').count()) === 3);
  check('roster labeled as mock data', (await page.textContent('#auth-card')).includes('Mock roster'));
  await page.click('.roster-btn[data-key="charlie"]');
  await page.fill('#lastname-input', 'wrongname');
  await page.click('#confirm-btn');
  check('wrong last name rejected', (await page.textContent('#auth-error')).includes('does not match'));
  await page.fill('#lastname-input', 'Charlie');
  await page.click('#confirm-btn');
  await page.waitForSelector('#app-shell:not([hidden])');
  const prodAccounts = await page.locator('.entity-row').count();
  check('producer sees only their own accounts', prodAccounts > 0 && prodAccounts < 136, 'saw ' + prodAccounts);
  const chipText = await page.textContent('#user-chip');
  check('producer chip shows role', chipText.includes('Producer'));
  check('no real broker names in mock incumbents', !(await page.content()).match(/\b(Aon|Gallagher|Alliant|Lockton|McGriff)\b/));

  /* console cleanliness (favicon 404s do not appear as console errors on file://) */
  check('zero console errors across the whole session', consoleErrors.length === 0, consoleErrors.slice(0, 3).join(' | '));

  await browser.close();
}

async function passWebglOff() {
  console.log('Pass 2: WebGL disabled via --disable-webgl');
  const browser = await chromium.launch({
    args: ['--disable-webgl', '--disable-webgl2', '--disable-3d-apis', '--disable-accelerated-2d-canvas']
  });
  const page = await browser.newPage();
  const consoleErrors = [];
  page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(m.text()); });
  page.on('pageerror', (e) => consoleErrors.push(String(e)));

  await page.goto(DIST);
  await page.waitForSelector('#code-input');
  await login(page, '5596');
  await page.waitForSelector('#app-shell:not([hidden])');

  const webgl = await page.evaluate(() => {
    const c = document.createElement('canvas');
    return !!(c.getContext('webgl') || c.getContext('experimental-webgl'));
  });
  check('WebGL is really unavailable in this pass', webgl === false);

  await page.click('.nav-tab[data-view="pipeline"]');
  await page.waitForSelector('tr[data-id]');
  await page.click('tr[data-id="city-philadelphia"]');
  await page.waitForSelector('#drawer:not([hidden])');
  await page.waitForTimeout(300);
  check('SVG elevation fallback renders instead of a canvas',
    (await page.locator('#viewer-wrap svg').count()) === 1 && (await page.locator('#viewer-wrap canvas').count()) === 0);
  check('fallback labels itself', (await page.textContent('#viewer-wrap')).includes('WebGL unavailable'));
  check('fallback draws one band per floor', (await page.locator('#viewer-wrap svg rect').count()) === 9, 'rects should be 9');
  await page.click('#drawer-close');

  await page.click('.nav-tab[data-view="verification"]');
  await page.click('.data-table tbody tr:first-child');
  await page.waitForSelector('#drawer:not([hidden])');
  await page.waitForTimeout(300);
  check('no-record empty state also renders with WebGL off', (await page.locator('.viewer-empty').count()) === 1);

  const fatal = consoleErrors.filter((e) => !/WebGL|GroupMarkerNotSet|swiftshader|GPU/i.test(e));
  check('no non-WebGL console errors with WebGL off', fatal.length === 0, fatal.slice(0, 3).join(' | '));

  await browser.close();
}

(async () => {
  await passWebglOn();
  await passWebglOff();
  if (failures) {
    console.log('\n' + failures + ' verification check(s) FAILED');
    process.exit(1);
  }
  console.log('\nAll verification checks passed.');
})().catch((e) => { console.error(e); process.exit(1); });
