/* VANTAGE Public Sector Edition: Segments view.
   Seven sub-segment cards with totals; selecting one lists its accounts. */

window.V = window.V || {};
V.views = V.views || {};

(function (V) {
  'use strict';

  V.views.segments = function (root) {
    var ents = V.scope.entities();
    var segs = V.state.data.segments;

    var bySeg = {};
    ents.forEach(function (e) {
      (bySeg[e.seg] = bySeg[e.seg] || []).push(e);
    });

    root.innerHTML =
      '<div class="section-title-row"><h2>Sub-segments</h2>' +
      '<span class="card-sub">Seven public entity verticals. Select a card to list its accounts.</span></div>' +
      '<div class="seg-grid">' +
      segs.map(function (s) {
        var list = bySeg[s.key] || [];
        var tiv = list.reduce(function (sum, e) { return sum + e.tiv; }, 0);
        var noRec = list.filter(function (e) { return V.verifStatus(e) === 'no-record'; }).length;
        var sel = V.state.selectedSeg === s.key;
        return '<div class="card seg-card' + (sel ? ' selected' : '') + '" data-seg="' + s.key + '" style="border-top-color:' + s.accent + '">' +
          '<h3>' + s.label + '</h3>' +
          '<div class="seg-count" style="color:' + s.accent + '">' + list.length + '</div>' +
          '<div class="seg-stats">accounts in scope<br>TIV ' + V.fmt.money(tiv) +
          ' &middot; <span style="color:var(--gold)">' + noRec + ' no floor record</span></div>' +
          '</div>';
      }).join('') +
      '</div>' +
      '<div class="card" id="seg-detail"></div>';

    Array.prototype.forEach.call(root.querySelectorAll('.seg-card'), function (card) {
      card.addEventListener('click', function () {
        var key = card.getAttribute('data-seg');
        V.state.selectedSeg = V.state.selectedSeg === key ? null : key;
        V.renderShell();
      });
    });

    var detail = document.getElementById('seg-detail');
    var selected = V.state.selectedSeg ? V.segByKey(V.state.selectedSeg) : null;
    if (!selected) {
      detail.innerHTML = '<div class="view-note">Select a segment card to see its account list, or use the Prospect Map to slice by state.</div>';
      return;
    }
    var list = (bySeg[selected.key] || []).slice().sort(function (a, b) { return b.tiv - a.tiv; });
    detail.innerHTML =
      '<h3>' + selected.label + ' (' + list.length + ')</h3>' +
      '<table class="data-table"><thead><tr>' +
      '<th>Entity</th><th>Location</th><th>' + selected.metricLabel + '</th><th>TIV (derived)</th><th>Status</th>' +
      '</tr></thead><tbody>' +
      list.map(function (e) {
        var status = V.verifStatus(e);
        return '<tr data-id="' + e.id + '">' +
          '<td>' + V.fmt.esc(e.name) + '</td>' +
          '<td>' + V.fmt.esc(e.city) + ', ' + e.state + '</td>' +
          '<td>' + V.fmt.int(e[selected.metricKey]) + '</td>' +
          '<td style="color:var(--gold);font-weight:700">' + V.fmt.money(e.tiv) + '</td>' +
          '<td><span class="status-chip status-' + status + '">' + status.replace('-', ' ') + '</span></td>' +
          '</tr>';
      }).join('') +
      '</tbody></table>';
    Array.prototype.forEach.call(detail.querySelectorAll('tr[data-id]'), function (row) {
      row.addEventListener('click', function () { V.drawer.open(row.getAttribute('data-id')); });
    });
  };
})(window.V);
