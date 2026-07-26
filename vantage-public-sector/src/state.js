/* VANTAGE Public Sector Edition: central app state, data loading, shell. */
/* All modules attach to the shared V namespace. No module system is used
   so the dev entry and the single-file bundle run the exact same code. */

window.V = window.V || {};

(function (V) {
  'use strict';

  /* Some hosts (embedded viewers, wrapper pages) strip or omit the head
     viewport tag; without it, phones lay the app out at desktop width.
     A dynamically inserted viewport meta is honored by mobile Safari and
     Chrome, so guarantee one exists before anything renders. */
  if (!document.querySelector('meta[name="viewport"]')) {
    var vp = document.createElement('meta');
    vp.name = 'viewport';
    vp.content = 'width=device-width, initial-scale=1.0';
    (document.head || document.documentElement).appendChild(vp);
  }

  var LS_VERIF = 'vantage_ps_verif';
  var LS_POOL = 'vantage_ps_poolbps';

  V.state = {
    data: null,          /* {entities, segments, gdp, producers, sources} */
    user: null,          /* {role: 'admin'|'producer', name, producerKey} */
    view: 'map',
    mapMode: 'market',   /* 'market' | 'geo' */
    selectedState: null,
    selectedSeg: null,
    poolBps: 1.8,        /* premium pool assumption, editable on the map view */
    drawerId: null,
    drawerTab: 'property',
    pipelineSort: { key: 'tiv', dir: -1 },
    verifOverrides: {}
  };

  /* ---------------- formatting helpers ---------------- */

  V.fmt = {
    money: function (n) {
      if (n === null || n === undefined) return 'n/a';
      if (n >= 1e9) return '$' + (n / 1e9).toFixed(n >= 1e10 ? 0 : 1) + 'B';
      if (n >= 1e6) return '$' + Math.round(n / 1e6) + 'M';
      if (n >= 1e3) return '$' + Math.round(n / 1e3) + 'K';
      return '$' + Math.round(n);
    },
    int: function (n) {
      if (n === null || n === undefined) return 'n/a';
      return Number(n).toLocaleString('en-US');
    },
    esc: function (s) {
      return String(s).replace(/[&<>"']/g, function (c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
      });
    }
  };

  V.segByKey = function (key) {
    var segs = V.state.data.segments;
    for (var i = 0; i < segs.length; i++) if (segs[i].key === key) return segs[i];
    return null;
  };

  V.entityById = function (id) {
    var list = V.state.data.entities;
    for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i];
    return null;
  };

  V.modeledBadge = function () {
    return '<span class="badge-modeled" title="Modeled placeholder. Synthetic value, not research.">&#9670; MODELED</span>';
  };

  /* ---------------- verification status ---------------- */

  /* Effective status: a no-record entity stays no-record until its floor
     count dispute is resolved; overrides record verify/flag actions. */
  V.verifStatus = function (entity) {
    var o = V.state.verifOverrides[entity.id];
    if (o && o.status) return o.status;
    return entity.verif;
  };

  V.setVerif = function (entityId, status, flag) {
    V.state.verifOverrides[entityId] = { status: status, flag: flag || null, ts: new Date().toISOString() };
    V.persist();
    V.renderShell();
  };

  V.clearVerif = function (entityId) {
    delete V.state.verifOverrides[entityId];
    V.persist();
    V.renderShell();
  };

  V.persist = function () {
    try {
      localStorage.setItem(LS_VERIF, JSON.stringify(V.state.verifOverrides));
      localStorage.setItem(LS_POOL, String(V.state.poolBps));
    } catch (e) { /* private mode: state stays in memory */ }
  };

  V.restore = function () {
    try {
      var v = localStorage.getItem(LS_VERIF);
      if (v) V.state.verifOverrides = JSON.parse(v);
      var p = parseFloat(localStorage.getItem(LS_POOL));
      if (!isNaN(p) && p > 0) V.state.poolBps = p;
    } catch (e) { /* ignore */ }
  };

  /* ---------------- data loading ---------------- */

  V.loadData = function () {
    if (window.VANTAGE_DATA) {
      V.state.data = normalize(window.VANTAGE_DATA);
      return Promise.resolve(V.state.data);
    }
    var segFiles = ['city', 'transit', 'water', 'highered', 'health', 'fed', 'air'];
    var urls = ['data/gdp-by-state.json', 'data/segments.json', 'data/producers.json', 'data/sources.json']
      .concat(segFiles.map(function (s) { return 'data/entities/' + s + '.json'; }));
    return Promise.all(urls.map(function (u) {
      return fetch(u).then(function (r) {
        if (!r.ok) throw new Error('Failed to load ' + u);
        return r.json();
      });
    })).then(function (parts) {
      var raw = {
        gdp: parts[0],
        segments: parts[1],
        producers: parts[2],
        sources: parts[3],
        entities: [].concat(parts[4], parts[5], parts[6], parts[7], parts[8], parts[9], parts[10])
      };
      V.state.data = normalize(raw);
      return V.state.data;
    });
  };

  function normalize(raw) {
    return {
      entities: raw.entities,
      segments: raw.segments,
      gdp: raw.gdp.gdp,
      gdpMeta: raw.gdp,
      regions: raw.gdp.regions,
      stateNames: raw.gdp.names,
      producers: raw.producers,
      sources: raw.sources.sources,
      sourcesNote: raw.sources.compileNote
    };
  }

  /* ---------------- KPI strip ---------------- */

  V.renderKpis = function () {
    var root = document.getElementById('kpi-strip');
    if (!root || !V.state.user) return;
    var ents = V.scope.entities();
    var totalTiv = 0, flagged = 0, noRecord = 0;
    ents.forEach(function (e) {
      totalTiv += e.tiv;
      var s = V.verifStatus(e);
      if (s === 'flagged') flagged++;
      if (s === 'no-record') noRecord++;
    });
    var pool = V.scope.premiumPool();
    root.innerHTML =
      kpi('Accounts in Scope', V.fmt.int(ents.length), false) +
      kpi('Total Insured Value', V.fmt.money(totalTiv), false) +
      kpi('Est. Premium Pool (' + V.state.poolBps + ' bps)', V.fmt.money(pool), false) +
      kpi('Flagged Discrepancies', V.fmt.int(flagged), flagged > 0) +
      kpi('Structures With No Floor Record', V.fmt.int(noRecord), noRecord > 0);
  };

  function kpi(label, value, alert) {
    return '<div class="kpi' + (alert ? ' kpi-alert' : '') + '">' +
      '<div class="kpi-label">' + label + '</div>' +
      '<div class="kpi-value">' + value + '</div></div>';
  }

  /* ---------------- navigation and shell ---------------- */

  var VIEWS = [
    { key: 'map', label: 'Prospect Map' },
    { key: 'segments', label: 'Segments' },
    { key: 'pipeline', label: 'Pipeline' },
    { key: 'verification', label: 'Verification' }
  ];

  V.go = function (view) {
    V.state.view = view;
    V.renderShell();
  };

  /* Rendering is deferred to a microtask and guarded against re-entry.
     Replacing a focused input mid-event makes the browser fire a second
     change event against a detached node; deferring sidesteps that. */
  var renderScheduled = false;
  V.renderShell = function () {
    if (renderScheduled) return;
    renderScheduled = true;
    Promise.resolve().then(function () {
      renderScheduled = false;
      renderShellNow();
    });
  };

  function renderShellNow() {
    if (!V.state.user) return;
    var tabs = document.getElementById('nav-tabs');
    var queueCount = V.scope.entities().filter(function (e) {
      var s = V.verifStatus(e);
      return s === 'no-record' || s === 'flagged';
    }).length;
    tabs.innerHTML = VIEWS.map(function (v) {
      var badge = v.key === 'verification' && queueCount > 0
        ? '<span class="nav-badge">' + queueCount + '</span>' : '';
      return '<button class="nav-tab' + (V.state.view === v.key ? ' active' : '') + '" data-view="' + v.key + '">' + v.label + badge + '</button>';
    }).join('');
    Array.prototype.forEach.call(tabs.querySelectorAll('.nav-tab'), function (btn) {
      btn.addEventListener('click', function () { V.go(btn.getAttribute('data-view')); });
    });

    var chip = document.getElementById('user-chip');
    chip.innerHTML = '<span class="user-name">' + V.fmt.esc(V.state.user.name) + '</span>' +
      '<span class="user-role">' + (V.state.user.role === 'admin' ? 'Admin' : 'Producer') + '</span>' +
      '<button class="btn btn-ghost btn-sm" id="logout-btn">Sign out</button>';
    document.getElementById('logout-btn').addEventListener('click', V.auth.logout);

    V.renderKpis();

    var root = document.getElementById('view-root');
    if (V.state.view === 'map') V.views.map(root);
    else if (V.state.view === 'segments') V.views.segments(root);
    else if (V.state.view === 'pipeline') V.views.pipeline(root);
    else if (V.state.view === 'verification') V.views.verification(root);

    if (V.state.drawerId) V.drawer.render();
  }

  /* ---------------- tooltip ---------------- */

  /* Hover tooltips make no sense on touch screens: the synthetic
     mousemove before a tap would leave a tooltip stuck over the UI. */
  var touchOnly = window.matchMedia && window.matchMedia('(hover: none)').matches;
  var tipEl = null;
  V.tip = {
    show: function (html, x, y) {
      if (touchOnly) return;
      if (!tipEl) {
        tipEl = document.createElement('div');
        tipEl.className = 'map-tip';
        document.body.appendChild(tipEl);
      }
      tipEl.innerHTML = html;
      tipEl.style.left = Math.min(x + 14, window.innerWidth - 280) + 'px';
      tipEl.style.top = (y + 14) + 'px';
      tipEl.style.display = 'block';
    },
    hide: function () { if (tipEl) tipEl.style.display = 'none'; }
  };

  /* ---------------- boot ---------------- */

  V.boot = function () {
    V.restore();
    V.loadData().then(function () {
      V.auth.renderLogin();
    }).catch(function (err) {
      document.getElementById('auth-screen').innerHTML =
        '<div class="auth-card"><p class="auth-error">Failed to load data: ' + V.fmt.esc(err.message) + '</p>' +
        '<p class="auth-label">If you opened index.html from disk, run npm run dev and use the local server. The dist bundle has no such requirement.</p></div>';
    });
  };
})(window.V);
