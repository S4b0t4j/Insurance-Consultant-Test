/* VANTAGE Public Sector Edition: Geographic view.
   Real US borders from the US Atlas TopoJSON (Census Bureau cartographic
   boundaries), pre-projected with the standard d3 geoAlbersUsa composite
   (Albers equal-area conic for the lower 48, with the conventional Alaska
   and Hawaii insets). Entity markers use coordinates projected with the
   exact same projection at data-build time (scripts/build-geo.mjs), so
   markers and borders align by construction. Marker radius scales with
   total insured value. */

window.V = window.V || {};

(function (V) {
  'use strict';

  V.geo = {};

  function markerRadius(tiv) {
    return Math.max(3.2, Math.min(22, Math.sqrt(tiv / 1e9) * 2.4));
  }

  V.geo.render = function (container) {
    var borders = V.state.data.borders;
    var segAccent = {};
    V.state.data.segments.forEach(function (s) { segAccent[s.key] = s.accent; });
    var scopeStates = {};
    V.scope.states().forEach(function (st) { scopeStates[st] = true; });

    var svg = ['<svg viewBox="' + borders.viewBox + '" role="img" aria-label="Geographic map: entities at real coordinates on US Census state boundaries, Albers equal-area conic projection">'];

    /* landmass and borders: dark fill on the card, visible outline */
    svg.push('<path class="geo-nation" d="' + borders.nation + '"/>');
    svg.push('<path class="geo-states" d="' + borders.states + '"/>');

    /* state code labels at planar centroids, dimmed outside scope */
    Object.keys(borders.labels).forEach(function (st) {
      var c = borders.labels[st];
      var opacity = scopeStates[st] ? 0.9 : 0.35;
      svg.push('<text class="geo-label" x="' + c[0] + '" y="' + c[1] + '" text-anchor="middle" opacity="' + opacity + '">' + st + '</text>');
    });

    /* entity markers, largest first so small ones stay clickable on top */
    var ents = V.scope.filtered().slice().sort(function (a, b) { return b.tiv - a.tiv; });
    ents.forEach(function (e) {
      var p = borders.points[e.id];
      if (!p) return;
      svg.push('<circle class="geo-marker" data-id="' + e.id + '" cx="' + p[0] + '" cy="' + p[1] + '" r="' + markerRadius(e.tiv).toFixed(1) + '" fill="' + segAccent[e.seg] + '"/>');
    });

    svg.push('</svg>');
    container.innerHTML = svg.join('');

    Array.prototype.forEach.call(container.querySelectorAll('.geo-marker'), function (el) {
      var id = el.getAttribute('data-id');
      el.addEventListener('click', function () { V.drawer.open(id); });
      el.addEventListener('mousemove', function (ev) {
        var e = V.entityById(id);
        var seg = V.segByKey(e.seg);
        V.tip.show('<b>' + V.fmt.esc(e.name) + '</b><div class="tip-sub">' +
          V.fmt.esc(e.city) + ', ' + e.state + ' &middot; ' + seg.label +
          '<br>TIV ' + V.fmt.money(e.tiv) + ' (derived)</div>', ev.clientX, ev.clientY);
      });
      el.addEventListener('mouseleave', V.tip.hide);
    });
  };
})(window.V);
