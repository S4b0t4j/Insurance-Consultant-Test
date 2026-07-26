/* VANTAGE Public Sector Edition: Geographic view.
   Albers equal-area conic projection for the continental US, with scaled
   inset projections for Alaska and Hawaii. Entities plot at their real
   coordinates; marker radius scales with total insured value. */

window.V = window.V || {};

(function (V) {
  'use strict';

  V.geo = {};

  var RAD = Math.PI / 180;

  /* Spherical Albers equal-area conic. Returns unit-sphere x/y (y down). */
  function albersFactory(lat0, lng0, phi1, phi2) {
    var p1 = phi1 * RAD, p2 = phi2 * RAD, l0 = lng0 * RAD, f0 = lat0 * RAD;
    var n = (Math.sin(p1) + Math.sin(p2)) / 2;
    var C = Math.cos(p1) * Math.cos(p1) + 2 * n * Math.sin(p1);
    var rho0 = Math.sqrt(C - 2 * n * Math.sin(f0)) / n;
    return function (lat, lng) {
      var phi = lat * RAD, lam = lng * RAD;
      var rho = Math.sqrt(C - 2 * n * Math.sin(phi)) / n;
      var theta = n * (lam - l0);
      return { x: rho * Math.sin(theta), y: rho0 - rho * Math.cos(theta) };
    };
  }

  /* Standard US Albers parameters for the lower 48. */
  var conus = albersFactory(37.5, -96, 29.5, 45.5);
  var alaska = albersFactory(60, -154, 55, 65);
  var hawaii = albersFactory(20.9, -157, 19, 21);

  var W = 940, H = 600;

  var AK_BOX = { x: 12, y: H - 190, w: 230, h: 178 };
  var HI_BOX = { x: 258, y: H - 120, w: 160, h: 108 };

  /* CONUS fit: sample the lower-48 bounding box on the raw projection and
     scale it into the frame, leaving the bottom-left corner to the insets. */
  var FIT = (function () {
    var minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    for (var lat = 24.5; lat <= 49.5; lat += 1) {
      for (var lng = -124.8; lng <= -66.9; lng += 1) {
        var p = conus(lat, lng);
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
    }
    var frame = { x: 34, y: 26, w: W - 68, h: H - 160 };
    var scale = Math.min(frame.w / (maxX - minX), frame.h / (maxY - minY));
    return {
      scale: scale,
      tx: frame.x + (frame.w - (maxX - minX) * scale) / 2 - minX * scale,
      ty: frame.y + (frame.h - (maxY - minY) * scale) / 2 - minY * scale
    };
  })();
  var CONUS_SCALE = FIT.scale;
  var CONUS_TX = FIT.tx;
  var CONUS_TY = FIT.ty;

  /* Project any US coordinate to the SVG frame. geoOverride routes AK and
     HI points into their insets. */
  V.geo.project = function (lat, lng, override) {
    if (override === 'AK') {
      var a = alaska(lat, lng);
      return { x: AK_BOX.x + AK_BOX.w / 2 + a.x * 420, y: AK_BOX.y + AK_BOX.h / 2 + a.y * 420 };
    }
    if (override === 'HI') {
      var hRaw = hawaii(lat, lng);
      return { x: HI_BOX.x + HI_BOX.w / 2 + hRaw.x * 900, y: HI_BOX.y + HI_BOX.h / 2 + hRaw.y * 900 };
    }
    var p = conus(lat, lng);
    return { x: CONUS_TX + p.x * CONUS_SCALE, y: CONUS_TY + p.y * CONUS_SCALE };
  };

  /* Approximate state centroids for orientation labels on the projected
     plane. Coarse by design; markers, not centroids, carry the data. */
  var CENTROIDS = {
    AL: [32.8, -86.8], AZ: [34.3, -111.7], AR: [34.9, -92.4], CA: [37.2, -119.3],
    CO: [39.0, -105.5], CT: [41.6, -72.7], DE: [39.0, -75.5], DC: [38.9, -77.03],
    FL: [28.6, -82.4], GA: [32.6, -83.4], ID: [44.4, -114.6], IL: [40.0, -89.2],
    IN: [39.9, -86.3], IA: [42.0, -93.5], KS: [38.5, -98.4], KY: [37.5, -85.3],
    LA: [31.0, -92.0], ME: [45.4, -69.2], MD: [39.0, -76.8], MA: [42.3, -71.8],
    MI: [44.3, -85.4], MN: [46.3, -94.3], MS: [32.7, -89.7], MO: [38.4, -92.5],
    MT: [47.0, -109.6], NE: [41.5, -99.8], NV: [39.3, -116.6], NH: [43.7, -71.6],
    NJ: [40.2, -74.7], NM: [34.4, -106.1], NY: [42.9, -75.5], NC: [35.5, -79.4],
    ND: [47.4, -100.5], OH: [40.3, -82.8], OK: [35.6, -97.5], OR: [43.9, -120.6],
    PA: [40.9, -77.8], RI: [41.7, -71.5], SC: [33.9, -80.9], SD: [44.4, -100.2],
    TN: [35.8, -86.3], TX: [31.5, -99.3], UT: [39.3, -111.7], VT: [44.0, -72.7],
    VA: [37.5, -78.8], WA: [47.4, -120.4], WV: [38.6, -80.6], WI: [44.6, -89.9],
    WY: [43.0, -107.6]
  };

  function markerRadius(tiv) {
    return Math.max(3.2, Math.min(22, Math.sqrt(tiv / 1e9) * 2.4));
  }

  V.geo.render = function (container) {
    var segAccent = {};
    V.state.data.segments.forEach(function (s) { segAccent[s.key] = s.accent; });
    var scopeStates = {};
    V.scope.states().forEach(function (st) { scopeStates[st] = true; });

    var svg = ['<svg viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="Geographic map: entities at real coordinates, Albers equal-area conic projection">'];

    /* graticule over CONUS */
    for (var lat = 25; lat <= 50; lat += 5) {
      var pts = [];
      for (var lng = -125; lng <= -66; lng += 2) {
        var g = V.geo.project(lat, lng);
        pts.push(g.x.toFixed(1) + ',' + g.y.toFixed(1));
      }
      svg.push('<path class="graticule" d="M' + pts.join(' L') + '"/>');
    }
    for (var lng2 = -120; lng2 <= -70; lng2 += 10) {
      var pts2 = [];
      for (var lat2 = 24; lat2 <= 50; lat2 += 2) {
        var g2 = V.geo.project(lat2, lng2);
        pts2.push(g2.x.toFixed(1) + ',' + g2.y.toFixed(1));
      }
      svg.push('<path class="graticule" d="M' + pts2.join(' L') + '"/>');
    }

    /* state code labels at projected centroids */
    Object.keys(CENTROIDS).forEach(function (st) {
      var c = CENTROIDS[st];
      var p = V.geo.project(c[0], c[1]);
      var opacity = scopeStates[st] ? 1 : 0.35;
      svg.push('<text class="geo-label" x="' + p.x.toFixed(1) + '" y="' + p.y.toFixed(1) + '" text-anchor="middle" opacity="' + opacity + '">' + st + '</text>');
    });

    /* AK / HI insets */
    svg.push('<rect class="geo-inset" x="' + AK_BOX.x + '" y="' + AK_BOX.y + '" width="' + AK_BOX.w + '" height="' + AK_BOX.h + '"/>');
    svg.push('<text class="geo-label" x="' + (AK_BOX.x + 8) + '" y="' + (AK_BOX.y + 14) + '">AK</text>');
    svg.push('<rect class="geo-inset" x="' + HI_BOX.x + '" y="' + HI_BOX.y + '" width="' + HI_BOX.w + '" height="' + HI_BOX.h + '"/>');
    svg.push('<text class="geo-label" x="' + (HI_BOX.x + 8) + '" y="' + (HI_BOX.y + 14) + '">HI</text>');

    /* entity markers, small ones on top */
    var ents = V.scope.filtered().slice().sort(function (a, b) { return b.tiv - a.tiv; });
    ents.forEach(function (e) {
      var p = V.geo.project(e.lat, e.lng, e.geoOverride);
      svg.push('<circle class="geo-marker" data-id="' + e.id + '" cx="' + p.x.toFixed(1) + '" cy="' + p.y.toFixed(1) + '" r="' + markerRadius(e.tiv).toFixed(1) + '" fill="' + segAccent[e.seg] + '"/>');
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
