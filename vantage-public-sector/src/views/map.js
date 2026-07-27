/* VANTAGE Public Sector Edition: Prospect Map view.
   Market mode: GDP cartogram. Geographic mode: Albers projection.
   POOL_BPS (the premium pool assumption) is visible and editable here. */

window.V = window.V || {};
V.views = V.views || {};

(function (V) {
  'use strict';

  V.views.map = function (root) {
    var segs = V.state.data.segments;
    var isGlobe = V.state.mapMode === 'globe';
    V.globe.unmount();
    root.innerHTML =
      '<div class="map-layout">' +
      '<div class="card">' +
      '<div class="map-controls">' +
      '<div class="mode-toggle">' +
      '<button id="mode-market" class="' + (V.state.mapMode === 'market' ? 'active' : '') + '">Market view</button>' +
      '<button id="mode-geo" class="' + (V.state.mapMode === 'geo' ? 'active' : '') + '">Geographic view</button>' +
      '<button id="mode-globe" class="' + (isGlobe ? 'active' : '') + '">Global view</button>' +
      '</div>' +
      (!isGlobe && V.state.selectedState ? '<button class="btn btn-ghost btn-sm" id="clear-state">Clear ' + V.state.selectedState + ' filter</button>' : '') +
      (isGlobe ? '' :
        '<div class="pool-ctl"><label for="pool-bps">POOL_BPS</label>' +
        '<input id="pool-bps" type="number" step="0.1" min="0.1" value="' + V.state.poolBps + '" aria-label="Premium pool assumption in basis points of state GDP">' +
        '<span>bps of GDP &rarr;</span><span class="pool-out" id="pool-out"></span></div>') +
      '</div>' +
      '<div class="map-svg-wrap" id="map-canvas"></div>' +
      '<div class="legend" id="map-legend"></div>' +
      '</div>' +
      '<div class="card" id="map-side">' +
      (isGlobe ? '' :
        '<h3 id="list-title"></h3>' +
        '<div class="legend" id="seg-filter" style="margin:0 0 10px"></div>' +
        '<div class="entity-list" id="entity-list"></div>') +
      '</div>' +
      '</div>';

    document.getElementById('mode-market').addEventListener('click', function () {
      V.state.mapMode = 'market';
      V.renderShell();
    });
    document.getElementById('mode-geo').addEventListener('click', function () {
      V.state.mapMode = 'geo';
      V.renderShell();
    });
    document.getElementById('mode-globe').addEventListener('click', function () {
      V.state.mapMode = 'globe';
      V.renderShell();
    });

    if (isGlobe) {
      var legend = document.getElementById('map-legend');
      V.globe.render(document.getElementById('map-canvas'), document.getElementById('map-side'));
      legend.innerHTML = segs.map(function (s) {
        return '<span class="legend-item"><span class="swatch" style="background:' + s.accent + ';border-radius:50%"></span> ' + s.label + '</span>';
      }).join('') + '<span class="legend-item">orthographic globe &middot; Natural Earth coastlines &middot; US book detail stays in the Market and Geographic views</span>';
      return;
    }
    var clearBtn = document.getElementById('clear-state');
    if (clearBtn) clearBtn.addEventListener('click', function () {
      V.state.selectedState = null;
      V.renderShell();
    });

    var poolInput = document.getElementById('pool-bps');
    var poolOut = document.getElementById('pool-out');
    var setPoolOut = function () { poolOut.textContent = V.fmt.money(V.scope.premiumPool()); };
    setPoolOut();
    poolInput.addEventListener('change', function () {
      var v = parseFloat(poolInput.value);
      if (!isNaN(v) && v > 0) {
        V.state.poolBps = v;
        V.persist();
        V.renderShell();
      }
    });

    var canvas = document.getElementById('map-canvas');
    var legend = document.getElementById('map-legend');
    if (V.state.mapMode === 'market') {
      V.cartogram.render(canvas);
      legend.innerHTML =
        '<span class="legend-item"><span class="swatch" style="background:#0C3348"></span> low opportunity density</span>' +
        '<span class="legend-item"><span class="swatch" style="background:#04B4BF"></span> high</span>' +
        '<span class="legend-item"><span class="swatch" style="background:#FFBF00"></span> highest</span>' +
        '<span class="legend-item">tile area = state nominal GDP, grouped by BEA region &middot; density = in-scope TIV per billion GDP</span>';
    } else {
      V.geo.render(canvas);
      legend.innerHTML = segs.map(function (s) {
        return '<span class="legend-item"><span class="swatch" style="background:' + s.accent + ';border-radius:50%"></span> ' + s.label + '</span>';
      }).join('') + '<span class="legend-item">marker radius = total insured value &middot; Albers equal-area conic, Census cartographic boundaries</span>';
    }

    /* segment filter chips */
    var segFilter = document.getElementById('seg-filter');
    segFilter.innerHTML = segs.map(function (s) {
      var on = V.state.selectedSeg === s.key;
      return '<span class="legend-item" data-seg="' + s.key + '" style="cursor:pointer;padding:3px 8px;border:1px solid ' + (on ? s.accent : 'var(--rule)') + ';border-radius:3px;' + (on ? 'color:var(--sky)' : '') + '">' +
        '<span class="swatch" style="background:' + s.accent + '"></span>' + s.label + '</span>';
    }).join('');
    Array.prototype.forEach.call(segFilter.querySelectorAll('[data-seg]'), function (chip) {
      chip.addEventListener('click', function () {
        var key = chip.getAttribute('data-seg');
        V.state.selectedSeg = V.state.selectedSeg === key ? null : key;
        V.renderShell();
      });
    });

    renderList();
  };

  function renderList() {
    var ents = V.scope.filtered().slice().sort(function (a, b) { return b.tiv - a.tiv; });
    var title = document.getElementById('list-title');
    var scopeBits = [];
    if (V.state.selectedState) scopeBits.push(V.state.data.stateNames[V.state.selectedState]);
    if (V.state.selectedSeg) scopeBits.push(V.segByKey(V.state.selectedSeg).label);
    title.textContent = 'Accounts' + (scopeBits.length ? ': ' + scopeBits.join(', ') : '') + ' (' + ents.length + ')';

    var list = document.getElementById('entity-list');
    if (!ents.length) {
      list.innerHTML = '<div class="view-note">No accounts in this slice of your scope.</div>';
      return;
    }
    list.innerHTML = ents.map(function (e) {
      var seg = V.segByKey(e.seg);
      var status = V.verifStatus(e);
      return '<div class="entity-row" data-id="' + e.id + '">' +
        '<span class="seg-dot" style="background:' + seg.accent + '"></span>' +
        '<span><div class="ent-name">' + V.fmt.esc(e.name) + '</div>' +
        '<div class="ent-sub">' + V.fmt.esc(e.city) + ', ' + e.state +
        (status === 'no-record' ? ' &middot; <span style="color:var(--gold)">no floor record</span>' : '') +
        '</div></span>' +
        '<span class="ent-tiv">' + V.fmt.money(e.tiv) + '</span>' +
        '</div>';
    }).join('');
    Array.prototype.forEach.call(list.querySelectorAll('.entity-row'), function (row) {
      row.addEventListener('click', function () { V.drawer.open(row.getAttribute('data-id')); });
    });
  }
})(window.V);
