/* VANTAGE Public Sector Edition: Verification Queue.
   Missing data is the feature. Entities with no floor record carry the
   no-record status and sort above unverified records. Flagged
   discrepancies sit between the two. Verified records leave the queue. */

window.V = window.V || {};
V.views = V.views || {};

(function (V) {
  'use strict';

  var PRIORITY = { 'no-record': 0, flagged: 1, unverified: 2 };

  V.views.verification = function (root) {
    var ents = V.scope.entities();
    var counts = { 'no-record': 0, flagged: 0, unverified: 0, verified: 0 };
    var queue = [];

    ents.forEach(function (e) {
      var s = V.verifStatus(e);
      counts[s] = (counts[s] || 0) + 1;
      if (s !== 'verified') queue.push({ e: e, status: s });
    });

    queue.sort(function (a, b) {
      var p = PRIORITY[a.status] - PRIORITY[b.status];
      if (p !== 0) return p;
      return b.e.tiv - a.e.tiv;
    });

    root.innerHTML =
      '<div class="section-title-row"><h2>Verification Queue</h2>' +
      '<span class="card-sub">The schedule of values is incomplete before anyone quotes it. VANTAGE says exactly where.</span></div>' +
      '<div class="kpi-strip" style="padding:0 0 16px">' +
      kpi('No Floor Record', counts['no-record'], true) +
      kpi('Flagged Discrepancies', counts.flagged, counts.flagged > 0) +
      kpi('Awaiting Verification', counts.unverified, false) +
      kpi('Verified', counts.verified, false) +
      '</div>' +
      '<div class="card" style="overflow-x:auto">' +
      '<table class="data-table"><thead><tr>' +
      '<th>Priority</th><th>Entity</th><th>Primary structure</th><th>State</th><th>Issue</th><th>TIV</th><th></th>' +
      '</tr></thead><tbody>' +
      queue.map(function (row, i) {
        return '<tr data-id="' + row.e.id + '">' +
          '<td>' + (i + 1) + '</td>' +
          '<td>' + V.fmt.esc(row.e.name) + '</td>' +
          '<td>' + V.fmt.esc(row.e.site) + '</td>' +
          '<td>' + row.e.state + '</td>' +
          '<td>' + issueCell(row) + '</td>' +
          '<td style="color:var(--gold);font-weight:700">' + V.fmt.money(row.e.tiv) + '</td>' +
          '<td><button class="btn btn-ghost btn-sm">Open</button></td>' +
          '</tr>';
      }).join('') +
      '</tbody></table>' +
      (queue.length === 0 ? '<div class="view-note">Queue clear. Every record in scope is verified.</div>' : '') +
      '</div>';

    Array.prototype.forEach.call(root.querySelectorAll('tr[data-id]'), function (row) {
      row.addEventListener('click', function () { V.drawer.open(row.getAttribute('data-id')); });
    });
  };

  function issueCell(row) {
    if (row.status === 'no-record') {
      return '<span class="status-chip status-no-record">No floor record</span> <span style="color:var(--muted)">no public floor count exists for this structure</span>';
    }
    if (row.status === 'flagged') {
      var o = V.state.verifOverrides[row.e.id];
      var f = o && o.flag ? o.flag : null;
      return '<span class="status-chip status-flagged">Flagged</span> ' +
        (f ? '<span style="color:var(--muted)">' + V.fmt.esc(f.field) + ': schedule ' + V.fmt.esc(f.scheduled) + ', observed ' + V.fmt.esc(f.observed) + '</span>' : '');
    }
    return '<span class="status-chip status-unverified">Unverified</span> <span style="color:var(--muted)">awaiting field confirmation</span>';
  }

  function kpi(label, value, alert) {
    return '<div class="kpi' + (alert && value > 0 ? ' kpi-alert' : '') + '">' +
      '<div class="kpi-label">' + label + '</div>' +
      '<div class="kpi-value">' + value + '</div></div>';
  }
})(window.V);
