/* VANTAGE Public Sector Edition: entity drawer.
   Three tabs (Property, Opportunity, Generate), a Sources section listing
   the datasets behind the record, keyless Google deep links, and the
   property verification workflow (confirm or flag a discrepancy). */

window.V = window.V || {};

(function (V) {
  'use strict';

  V.drawer = {};

  var flagFormOpen = false;

  V.drawer.open = function (id) {
    V.tip.hide();
    V.state.drawerId = id;
    V.state.drawerTab = 'property';
    flagFormOpen = false;
    V.drawer.render();
  };

  V.drawer.close = function () {
    V.viewer3d.unmount();
    V.state.drawerId = null;
    var d = document.getElementById('drawer');
    var o = document.getElementById('drawer-overlay');
    if (d) d.hidden = true;
    if (o) o.hidden = true;
  };

  V.drawer.render = function () {
    var e = V.entityById(V.state.drawerId);
    if (!e) return V.drawer.close();
    V.viewer3d.unmount();

    var seg = V.segByKey(e.seg);
    var status = V.verifStatus(e);
    var d = document.getElementById('drawer');
    var o = document.getElementById('drawer-overlay');
    d.hidden = false;
    o.hidden = false;
    o.onclick = V.drawer.close;

    var producerName = '';
    V.state.data.producers.forEach(function (p) { if (p.key === e.producer) producerName = p.name; });

    var tabs = [
      { key: 'property', label: 'Property' },
      { key: 'opportunity', label: 'Opportunity' },
      { key: 'generate', label: 'Generate' }
    ];

    d.innerHTML =
      '<div class="drawer-head"><h2>' + V.fmt.esc(e.name) + '</h2>' +
      '<button class="drawer-close" id="drawer-close" aria-label="Close">&times;</button></div>' +
      '<div class="drawer-meta">' +
      '<span class="seg-chip" style="background:' + seg.accent + '">' + V.fmt.esc(seg.label) + '</span>' +
      '<span>' + V.fmt.esc(e.city) + ', ' + e.state + '</span>' +
      '<span class="status-chip status-' + status + '">' + statusLabel(status) + '</span>' +
      (V.state.user.role === 'admin' ? '<span>Producer: ' + V.fmt.esc(producerName) + '</span>' : '') +
      '</div>' +
      '<div class="drawer-tabs">' + tabs.map(function (t) {
        return '<button class="drawer-tab' + (V.state.drawerTab === t.key ? ' active' : '') + '" data-tab="' + t.key + '">' + t.label + '</button>';
      }).join('') + '</div>' +
      '<div id="drawer-body"></div>' +
      sourcesSection(e);

    document.getElementById('drawer-close').addEventListener('click', V.drawer.close);
    Array.prototype.forEach.call(d.querySelectorAll('.drawer-tab'), function (btn) {
      btn.addEventListener('click', function () {
        V.state.drawerTab = btn.getAttribute('data-tab');
        flagFormOpen = false;
        V.drawer.render();
      });
    });

    var body = document.getElementById('drawer-body');
    if (V.state.drawerTab === 'property') renderProperty(body, e);
    else if (V.state.drawerTab === 'opportunity') renderOpportunity(body, e);
    else V.lenore.renderPanel(body, e);
  };

  function statusLabel(s) {
    return { 'no-record': 'No record', flagged: 'Flagged', unverified: 'Unverified', verified: 'Verified' }[s] || s;
  }

  /* ---------------- Property tab ---------------- */

  function renderProperty(body, e) {
    var seg = V.segByKey(e.seg);
    var status = V.verifStatus(e);
    var override = V.state.verifOverrides[e.id];

    body.innerHTML =
      '<div class="viewer-wrap" id="viewer-wrap"></div>' +
      '<div class="viewer-note" id="viewer-note"></div>' +
      '<div class="facts-grid">' +
      fact('Primary structure', e.site, false) +
      fact('Floors on record', e.floors === null ? null : V.fmt.int(e.floors), false) +
      fact('Height', e.height === null ? null : e.height + ' ft', false) +
      fact('Square footage', e.sqft === null ? null : V.fmt.int(e.sqft) + ' sq ft', false) +
      fact('Year built', e.built, false) +
      fact('Construction', e.constr, false) +
      fact('Roof', e.roof, false) +
      fact(seg.metricLabel, V.fmt.int(e[seg.metricKey]), false) +
      '</div>' +
      deepLinks(e) +
      verifBox(e, status, override);

    var wrap = document.getElementById('viewer-wrap');
    var mode = V.viewer3d.mount(wrap, e);
    var note = document.getElementById('viewer-note');
    if (mode === '3d') note.textContent = 'Massing: each visible band is one floor on record. Drag to rotate.';
    else if (mode === 'svg') note.textContent = 'WebGL unavailable in this browser. Showing the 2D elevation fallback.';
    else note.textContent = 'No massing is shown because no floor count is on record.';

    wireVerifActions(e);
  }

  function fact(label, value, isNull) {
    var missing = value === null || value === undefined;
    return '<div class="fact"><div class="fact-label">' + label + '</div>' +
      '<div class="fact-value' + (missing ? ' fact-null' : '') + '">' +
      (missing ? 'No public record' : V.fmt.esc(String(value))) + '</div></div>';
  }

  function deepLinks(e) {
    var ll = e.lat + ',' + e.lng;
    return '<div class="deep-links">' +
      '<a class="deep-link" target="_blank" rel="noopener" href="https://www.google.com/maps/search/?api=1&amp;query=' + ll + '">Google Maps</a>' +
      '<a class="deep-link" target="_blank" rel="noopener" href="https://www.google.com/maps/@?api=1&amp;map_action=pano&amp;viewpoint=' + ll + '">Street View</a>' +
      '<a class="deep-link" target="_blank" rel="noopener" href="https://earth.google.com/web/@' + e.lat + ',' + e.lng + ',0a,900d,35y,0h,45t,0r">Google Earth</a>' +
      '</div>';
  }

  function verifBox(e, status, override) {
    var html = '<div class="verif-box"><div class="verif-title">Property verification</div>';
    if (status === 'flagged' && override && override.flag) {
      html += '<div class="flag-detail">Discrepancy flagged on <b>' + V.fmt.esc(override.flag.field) + '</b>: schedule shows <b>' +
        V.fmt.esc(override.flag.scheduled) + '</b>, observed <b>' + V.fmt.esc(override.flag.observed) + '</b>.' +
        (override.flag.note ? '<br>Note: ' + V.fmt.esc(override.flag.note) : '') + '</div>';
      html += '<div class="verif-actions" style="margin-top:10px">' +
        '<button class="btn btn-sm" id="verif-confirm">Resolve as accurate</button>' +
        '<button class="btn btn-ghost btn-sm" id="verif-reset">Clear flag</button></div>';
    } else if (status === 'verified') {
      html += '<div class="flag-detail">Record confirmed as accurate against observed reality.</div>';
      html += '<div class="verif-actions" style="margin-top:10px">' +
        '<button class="btn btn-ghost btn-sm" id="verif-reset">Reopen</button></div>';
    } else {
      if (status === 'no-record') {
        html += '<div class="flag-detail">Highest queue priority: <b>no floor record</b> exists for this structure. ' +
          'Confirm the floor count on site, or flag what you observe.</div>';
      }
      html += '<div class="verif-actions" style="margin-top:10px">' +
        '<button class="btn btn-sm" id="verif-confirm">Confirm as accurate</button>' +
        '<button class="btn btn-gold btn-sm" id="verif-flag">Flag a discrepancy</button></div>';
      if (flagFormOpen) {
        html += '<div class="flag-form" id="flag-form">' +
          '<select id="flag-field">' +
          ['floors', 'height', 'sqft', 'built', 'constr', 'roof', 'site'].map(function (f) {
            return '<option value="' + f + '">' + f + '</option>';
          }).join('') + '</select>' +
          '<input id="flag-observed" type="text" placeholder="Observed value (what you saw)">' +
          '<textarea id="flag-note" rows="2" placeholder="Note (optional)"></textarea>' +
          '<div><button class="btn btn-sm" id="flag-submit">Submit flag</button></div>' +
          '</div>';
      }
    }
    return html + '</div>';
  }

  function wireVerifActions(e) {
    var confirmBtn = document.getElementById('verif-confirm');
    if (confirmBtn) confirmBtn.addEventListener('click', function () {
      V.setVerif(e.id, 'verified');
      V.drawer.render();
    });
    var resetBtn = document.getElementById('verif-reset');
    if (resetBtn) resetBtn.addEventListener('click', function () {
      V.clearVerif(e.id);
      V.drawer.render();
    });
    var flagBtn = document.getElementById('verif-flag');
    if (flagBtn) flagBtn.addEventListener('click', function () {
      flagFormOpen = !flagFormOpen;
      V.drawer.render();
    });
    var submitBtn = document.getElementById('flag-submit');
    if (submitBtn) submitBtn.addEventListener('click', function () {
      var field = document.getElementById('flag-field').value;
      var observed = document.getElementById('flag-observed').value.trim() || 'not stated';
      var note = document.getElementById('flag-note').value.trim();
      var scheduled = e[field] === null || e[field] === undefined ? 'no record' : String(e[field]);
      flagFormOpen = false;
      V.setVerif(e.id, 'flagged', { field: field, scheduled: scheduled, observed: observed, note: note });
      V.drawer.render();
    });
  }

  /* ---------------- Opportunity tab ---------------- */

  function renderOpportunity(body, e) {
    var seg = V.segByKey(e.seg);
    var prov = e.provenance || {};
    var tivFormula = prov.tiv && prov.tiv.formula ? prov.tiv.formula : '';
    var premFormula = prov.prem && prov.prem.formula ? prov.prem.formula : '';

    body.innerHTML =
      '<div class="opp-rows">' +
      oppRow(seg.metricLabel, V.fmt.int(e[seg.metricKey]), '', 'Public value. Source: ' + srcName(prov[seg.metricKey])) +
      oppRow('Total insured value', V.fmt.money(e.tiv), 'opp-money', 'Derived. ' + tivFormula) +
      oppRow('Est. annual premium', V.fmt.money(e.prem), 'opp-money', 'Derived. ' + premFormula) +
      oppRowModeled('Incumbent broker', e.inc) +
      oppRowModeled('Renewal date', e.renew) +
      oppRowModeled('Trigger', e.trigger) +
      '</div>' +
      '<div class="view-note" style="margin-top:14px">Derived values carry their formula in the tooltip. ' +
      'Values marked ' + V.modeledBadge() + ' are synthetic placeholders and are never client-ready research.</div>';
  }

  function oppRow(label, value, cls, title) {
    return '<div class="opp-row" title="' + V.fmt.esc(title) + '">' +
      '<span class="opp-label">' + label + '</span>' +
      '<span class="opp-value ' + cls + '">' + V.fmt.esc(String(value)) + '</span>' +
      (title.indexOf('Derived') === 0 ? '<span class="derived-mark" style="color:var(--active-blue);font-size:11px" title="' + V.fmt.esc(title) + '">&fnof; derived</span>' : '') +
      '</div>';
  }

  function oppRowModeled(label, value) {
    return '<div class="opp-row"><span class="opp-label">' + label + '</span>' +
      '<span class="opp-value">' + V.fmt.esc(String(value)) + '</span>' + V.modeledBadge() + '</div>';
  }

  function srcName(p) {
    if (!p || !p.source) return 'not stated';
    var s = V.state.data.sources[p.source];
    return s ? s.name : p.source;
  }

  /* ---------------- Sources section ---------------- */

  function sourcesSection(e) {
    var prov = e.provenance || {};
    var used = {};
    Object.keys(prov).forEach(function (field) {
      var p = prov[field];
      if (p.kind === 'public' && p.source) {
        (used[p.source] = used[p.source] || []).push(field);
      }
    });
    var sources = V.state.data.sources;
    var lines = Object.keys(used).map(function (key) {
      var s = sources[key] || { name: key, publisher: '', retrieved: '' };
      return '<div class="source-line"><b>' + V.fmt.esc(s.name) + '</b> (' + V.fmt.esc(s.publisher) + ', retrieved ' + V.fmt.esc(s.retrieved || 'n/a') + ')<br>fields: ' + used[key].join(', ') + '</div>';
    });
    var modeled = Object.keys(prov).filter(function (f) { return prov[f].kind === 'modeled'; });
    return '<div class="sources-box"><div class="sources-title">Sources behind this record</div>' +
      lines.join('') +
      '<div class="source-line"><b>Modeled placeholders</b> (no source, synthetic): ' + modeled.join(', ') + '</div>' +
      '</div>';
  }
})(window.V);
