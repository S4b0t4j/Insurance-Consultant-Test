/* VANTAGE Public Sector Edition: Pipeline view.
   Sortable account table across the user's scope. Modeled fields carry the
   persistent modeled badge so they are never mistaken for research. */

window.V = window.V || {};
V.views = V.views || {};

(function (V) {
  'use strict';

  var COLS = [
    { key: 'name', label: 'Entity', num: false },
    { key: 'seg', label: 'Segment', num: false },
    { key: 'state', label: 'State', num: false },
    { key: 'producer', label: 'Producer', num: false, adminOnly: true },
    { key: 'tiv', label: 'TIV', num: true },
    { key: 'prem', label: 'Est. Premium', num: true },
    { key: 'renew', label: 'Renewal', num: false, modeled: true },
    { key: 'inc', label: 'Incumbent', num: false, modeled: true },
    { key: 'status', label: 'Status', num: false }
  ];

  V.views.pipeline = function (root) {
    var isAdmin = V.state.user.role === 'admin';
    var cols = COLS.filter(function (c) { return !c.adminOnly || isAdmin; });
    var sort = V.state.pipelineSort;

    var producerNames = {};
    V.state.data.producers.forEach(function (p) { producerNames[p.key] = p.name; });

    var ents = V.scope.entities().map(function (e) {
      return {
        e: e,
        name: e.name, seg: V.segByKey(e.seg).label, state: e.state,
        producer: producerNames[e.producer] || e.producer,
        tiv: e.tiv, prem: e.prem, renew: e.renew, inc: e.inc,
        status: V.verifStatus(e)
      };
    });

    ents.sort(function (a, b) {
      var av = a[sort.key], bv = b[sort.key];
      if (typeof av === 'number') return (av - bv) * sort.dir;
      return String(av).localeCompare(String(bv)) * sort.dir;
    });

    root.innerHTML =
      '<div class="section-title-row"><h2>Pipeline</h2>' +
      '<span class="card-sub">' + ents.length + ' accounts in scope. Click a column to sort, a row to open the account.</span></div>' +
      '<div class="card" style="overflow-x:auto">' +
      '<table class="data-table"><thead><tr>' +
      cols.map(function (c) {
        var mark = sort.key === c.key ? (sort.dir === 1 ? ' &#9650;' : ' &#9660;') : '';
        return '<th data-key="' + c.key + '" class="' + (sort.key === c.key ? 'sorted' : '') + '">' + c.label + mark + '</th>';
      }).join('') +
      '</tr></thead><tbody>' +
      ents.map(function (row) {
        return '<tr data-id="' + row.e.id + '">' + cols.map(function (c) {
          if (c.key === 'tiv' || c.key === 'prem') {
            return '<td style="color:var(--gold);font-weight:700">' + V.fmt.money(row[c.key]) + '</td>';
          }
          if (c.modeled) {
            return '<td>' + V.fmt.esc(String(row[c.key])) + ' ' + V.modeledBadge() + '</td>';
          }
          if (c.key === 'status') {
            return '<td><span class="status-chip status-' + row.status + '">' + row.status.replace('-', ' ') + '</span></td>';
          }
          return '<td>' + V.fmt.esc(String(row[c.key])) + '</td>';
        }).join('') + '</tr>';
      }).join('') +
      '</tbody></table></div>';

    Array.prototype.forEach.call(root.querySelectorAll('th[data-key]'), function (th) {
      th.addEventListener('click', function () {
        var key = th.getAttribute('data-key');
        if (V.state.pipelineSort.key === key) V.state.pipelineSort.dir *= -1;
        else V.state.pipelineSort = { key: key, dir: key === 'tiv' || key === 'prem' ? -1 : 1 };
        V.renderShell();
      });
    });
    Array.prototype.forEach.call(root.querySelectorAll('tr[data-id]'), function (row) {
      row.addEventListener('click', function () { V.drawer.open(row.getAttribute('data-id')); });
    });
  };
})(window.V);
