/* VANTAGE Public Sector Edition: Global view.
   Orthographic globe on canvas, rotating counterclockwise, with dots for
   major public entities in cities worldwide (illustrative showcase layer)
   and a country legend that spins and zooms the globe to the selected
   country. Coastlines are Natural Earth 1:110M via world-atlas. The US
   Market and Geographic views are untouched. */

window.V = window.V || {};

(function (V) {
  'use strict';

  V.globe = {};

  var RAD = Math.PI / 180;
  var SPIN_DEG_PER_SEC = 4.5; /* counterclockwise: view center drifts west */

  var active = null; /* current mount */

  V.globe.unmount = function () {
    if (!active) return;
    if (active.raf) cancelAnimationFrame(active.raf);
    window.removeEventListener('pointermove', active.onMove);
    window.removeEventListener('pointerup', active.onUp);
    active = null;
  };

  /* Orthographic projection around view center [cLng, cLat].
     Returns {x, y, front} in unit-sphere space, y up. */
  function project(lat, lng, cLat, cLng) {
    var phi = lat * RAD, lam = (lng - cLng) * RAD, c = cLat * RAD;
    var cosPhi = Math.cos(phi);
    var front = Math.sin(c) * Math.sin(phi) + Math.cos(c) * cosPhi * Math.cos(lam);
    return {
      x: cosPhi * Math.sin(lam),
      y: Math.cos(c) * Math.sin(phi) - Math.sin(c) * cosPhi * Math.cos(lam),
      front: front >= 0
    };
  }

  function easeInOut(t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; }

  /* Shortest-path longitude interpolation. */
  function lerpLng(a, b, t) {
    var d = ((b - a + 540) % 360) - 180;
    return a + d * t;
  }

  V.globe.render = function (canvasHost, legendHost) {
    V.globe.unmount();

    var data = V.state.data.globalCities;
    var land = V.state.data.worldLand.polygons;
    var segAccent = {};
    V.state.data.segments.forEach(function (s) { segAccent[s.key] = s.accent; });

    var countryName = {};
    var countByCountry = {};
    data.countries.forEach(function (c) { countryName[c.code] = c.name; countByCountry[c.code] = 0; });
    data.cities.forEach(function (c) { countByCountry[c.country] = (countByCountry[c.country] || 0) + 1; });

    /* GDP influence: metro GDP x segment dependency weight (modeled
       assumption, documented in data/global-cities.json). Used to rank
       which public entities influence a metro economy most. */
    var weights = data.weights || {};
    function influence(city) {
      return (city.gdp || 0) * (weights[city.seg] || 0.02);
    }
    var maxInfluence = 0;
    data.cities.forEach(function (c) { maxInfluence = Math.max(maxInfluence, influence(c)); });
    var fmtB = function (v) {
      return '$' + (v >= 100 ? Math.round(v).toLocaleString('en-US') : v >= 10 ? Math.round(v) : v.toFixed(1)) + 'B';
    };

    canvasHost.innerHTML =
      '<canvas id="globe-canvas" aria-label="Rotating globe of major public entities worldwide, dots sized by metro GDP"></canvas>' +
      '<div class="globe-status" id="globe-status">Rotating. Drag the globe, or pick a country to spin and zoom to it. Dot size = metro GDP.</div>';
    var canvas = canvasHost.querySelector('#globe-canvas');
    var ctx = canvas.getContext('2d');
    var status = canvasHost.querySelector('#globe-status');

    legendHost.innerHTML =
      '<h3 id="globe-cities-title"></h3>' +
      '<div class="view-note" style="margin:0 0 10px">Showcase layer, display only. Metro GDP compiled from OECD and Brookings metro data. ' +
      'Influence est. = metro GDP x segment dependency weight, a placeholder assumption ' + V.modeledBadge() + '</div>' +
      '<div id="globe-cities"></div>' +
      '<div style="margin:12px 0"><button class="btn btn-ghost btn-sm" id="globe-reset">Resume rotation</button></div>' +
      '<h3>Countries</h3>' +
      '<div class="globe-legend" id="globe-legend">' +
      data.countries.map(function (c) {
        return '<button class="globe-country" data-code="' + c.code + '">' +
          '<span>' + V.fmt.esc(c.name) + '</span><span class="globe-count">' + (countByCountry[c.code] || 0) + '</span></button>';
      }).join('') +
      '</div>';

    function renderCityPanel(focusCode) {
      var title = legendHost.querySelector('#globe-cities-title');
      var host = legendHost.querySelector('#globe-cities');
      var list = focusCode
        ? data.cities.filter(function (c) { return c.country === focusCode; })
        : data.cities.slice();
      list.sort(function (a, b) { return influence(b) - influence(a); });
      if (!focusCode) list = list.slice(0, 10);
      title.textContent = focusCode
        ? countryName[focusCode] + ': entities by GDP influence'
        : 'Top GDP influence, global';
      host.innerHTML = list.map(function (c) {
        var seg = V.segByKey(c.seg);
        var infl = influence(c);
        var pct = maxInfluence > 0 ? Math.max(3, Math.round(infl / maxInfluence * 100)) : 0;
        return '<div class="gcity-row" data-code="' + c.country + '" title="Metro GDP compiled from OECD and Brookings. Influence est. = GDP x ' + ((weights[c.seg] || 0.02) * 100).toFixed(1) + ' percent ' + V.fmt.esc(seg ? seg.label : c.seg) + ' dependency weight (modeled).">' +
          '<div class="gcity-head"><span class="gcity-name">' + V.fmt.esc(c.entity) + '</span>' +
          '<span class="gcity-gdp">' + fmtB(c.gdp) + '</span></div>' +
          '<div class="gcity-sub">' + V.fmt.esc(c.city) + ', ' + V.fmt.esc(countryName[c.country] || c.country) +
          ' &middot; metro GDP ' + fmtB(c.gdp) + ' &middot; influence est. ' + fmtB(infl) + '</div>' +
          '<div class="gcity-bar"><span style="width:' + pct + '%;background:' + (seg ? seg.accent : '#04B4BF') + '"></span></div>' +
          '</div>';
      }).join('');
      Array.prototype.forEach.call(host.querySelectorAll('.gcity-row'), function (row) {
        row.addEventListener('click', function () { focusCountry(row.getAttribute('data-code')); });
      });
    }

    var state = {
      cLng: -30, cLat: 18,
      zoom: 1,
      focus: null,          /* country code when focused */
      spinning: true,
      anim: null,           /* {t0, dur, from:{lng,lat,zoom}, to:{lng,lat,zoom}} */
      dragging: false,
      lastX: 0, lastY: 0,
      dragIdleTimer: null,
      dotHits: [],
      raf: 0,
      lastTs: 0,
      onMove: null, onUp: null
    };
    active = state;

    function size() {
      var w = canvasHost.clientWidth || 600;
      var h = Math.max(320, Math.min(560, Math.round(w * 0.72)));
      var dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = w * dpr;
      canvas.height = h * dpr;
      canvas.style.width = w + 'px';
      canvas.style.height = h + 'px';
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      return { w: w, h: h };
    }
    var dims = size();

    function draw() {
      var w = dims.w, h = dims.h;
      var cx = w / 2, cy = h / 2;
      var R = Math.min(w, h) * 0.46 * state.zoom;
      ctx.clearRect(0, 0, w, h);

      /* sphere */
      ctx.beginPath();
      ctx.arc(cx, cy, R, 0, Math.PI * 2);
      ctx.fillStyle = '#00263A';
      ctx.fill();
      ctx.strokeStyle = 'rgba(206, 236, 255, 0.75)';
      ctx.lineWidth = 1.4;
      ctx.stroke();

      ctx.save();
      ctx.beginPath();
      ctx.arc(cx, cy, R, 0, Math.PI * 2);
      ctx.clip();

      /* graticule */
      ctx.strokeStyle = 'rgba(42, 80, 104, 0.8)';
      ctx.lineWidth = 0.5;
      var lat, lng, p, started;
      for (lat = -60; lat <= 60; lat += 30) {
        ctx.beginPath(); started = false;
        for (lng = -180; lng <= 180; lng += 5) {
          p = project(lat, lng, state.cLat, state.cLng);
          if (p.front) {
            var gx = cx + p.x * R, gy = cy - p.y * R;
            if (started) ctx.lineTo(gx, gy); else { ctx.moveTo(gx, gy); started = true; }
          } else started = false;
        }
        ctx.stroke();
      }
      for (lng = -180; lng < 180; lng += 30) {
        ctx.beginPath(); started = false;
        for (lat = -85; lat <= 85; lat += 5) {
          p = project(lat, lng, state.cLat, state.cLng);
          if (p.front) {
            var mx = cx + p.x * R, my = cy - p.y * R;
            if (started) ctx.lineTo(mx, my); else { ctx.moveTo(mx, my); started = true; }
          } else started = false;
        }
        ctx.stroke();
      }

      /* land: back-hemisphere points clamp to the limb so fills stay closed */
      ctx.fillStyle = '#0C3348';
      ctx.strokeStyle = 'rgba(206, 236, 255, 0.55)';
      ctx.lineWidth = 0.8;
      for (var i = 0; i < land.length; i++) {
        var poly = land[i];
        ctx.beginPath();
        var anyFront = false;
        for (var j = 0; j < poly.length; j++) {
          var ring = poly[j];
          for (var k = 0; k < ring.length; k++) {
            var pt = project(ring[k][1], ring[k][0], state.cLat, state.cLng);
            var x = pt.x, y = pt.y;
            if (!pt.front) {
              var n = Math.sqrt(x * x + y * y) || 1;
              x /= n; y /= n;
            } else anyFront = true;
            var px = cx + x * R, py = cy - y * R;
            if (k === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
          }
          ctx.closePath();
        }
        if (anyFront) { ctx.fill(); ctx.stroke(); }
      }
      ctx.restore();

      /* city dots */
      state.dotHits = [];
      for (var d = 0; d < data.cities.length; d++) {
        var city = data.cities[d];
        var cp = project(city.lat, city.lng, state.cLat, state.cLng);
        if (!cp.front) continue;
        var dx = cx + cp.x * R, dy = cy - cp.y * R;
        var focused = state.focus && city.country === state.focus;
        var r = 2.4 + Math.sqrt(city.gdp || 25) * 0.17 + (focused ? 1.5 : 0);
        ctx.beginPath();
        ctx.arc(dx, dy, r, 0, Math.PI * 2);
        ctx.fillStyle = segAccent[city.seg] || '#04B4BF';
        ctx.globalAlpha = state.focus && !focused ? 0.45 : 0.95;
        ctx.fill();
        ctx.globalAlpha = 1;
        ctx.lineWidth = focused ? 2 : 1;
        ctx.strokeStyle = focused ? '#FFBF00' : '#00263A';
        ctx.stroke();
        state.dotHits.push({ x: dx, y: dy, r: r + 5, city: city });
      }
    }

    function tick(ts) {
      if (active !== state) return;
      if (!canvas.isConnected) { V.globe.unmount(); return; }
      var dt = state.lastTs ? Math.min(0.1, (ts - state.lastTs) / 1000) : 0;
      state.lastTs = ts;

      if (state.anim) {
        var a = state.anim;
        var t = Math.min(1, (ts - a.t0) / a.dur);
        var e = easeInOut(t);
        state.cLng = lerpLng(a.from.lng, a.to.lng, e);
        state.cLat = a.from.lat + (a.to.lat - a.from.lat) * e;
        state.zoom = a.from.zoom + (a.to.zoom - a.from.zoom) * e;
        if (t >= 1) state.anim = null;
      } else if (state.spinning && !state.dragging) {
        state.cLng -= SPIN_DEG_PER_SEC * dt;
        if (state.cLng < -180) state.cLng += 360;
      }
      draw();
      state.raf = requestAnimationFrame(tick);
    }

    function focusCountry(code) {
      var target = null;
      data.countries.forEach(function (c) { if (c.code === code) target = c; });
      if (!target) return;
      state.focus = code;
      state.spinning = false;
      state.anim = {
        t0: performance.now(), dur: 1300,
        from: { lng: state.cLng, lat: state.cLat, zoom: state.zoom },
        to: { lng: target.lng, lat: target.lat, zoom: target.zoom || 1.9 }
      };
      status.textContent = countryName[code] + ': ' + (countByCountry[code] || 0) + ' showcase ' +
        ((countByCountry[code] || 0) === 1 ? 'entity' : 'entities') + '. Rotation paused.';
      Array.prototype.forEach.call(legendHost.querySelectorAll('.globe-country'), function (b) {
        b.classList.toggle('active', b.getAttribute('data-code') === code);
      });
      renderCityPanel(code);
    }

    function reset() {
      state.focus = null;
      state.anim = {
        t0: performance.now(), dur: 900,
        from: { lng: state.cLng, lat: state.cLat, zoom: state.zoom },
        to: { lng: state.cLng, lat: 18, zoom: 1 }
      };
      state.spinning = true;
      status.textContent = 'Rotating. Drag the globe, or pick a country to spin and zoom to it. Dot size = metro GDP.';
      Array.prototype.forEach.call(legendHost.querySelectorAll('.globe-country'), function (b) {
        b.classList.remove('active');
      });
      renderCityPanel(null);
    }

    /* interactions */
    Array.prototype.forEach.call(legendHost.querySelectorAll('.globe-country'), function (btn) {
      btn.addEventListener('click', function () { focusCountry(btn.getAttribute('data-code')); });
    });
    legendHost.querySelector('#globe-reset').addEventListener('click', reset);

    canvas.addEventListener('pointerdown', function (ev) {
      state.dragging = true;
      state.lastX = ev.clientX;
      state.lastY = ev.clientY;
    });
    state.onMove = function (ev) {
      if (!state.dragging) return;
      var R = Math.min(dims.w, dims.h) * 0.46 * state.zoom;
      state.cLng -= (ev.clientX - state.lastX) * (60 / R);
      state.cLat = Math.max(-75, Math.min(75, state.cLat + (ev.clientY - state.lastY) * (60 / R)));
      state.lastX = ev.clientX;
      state.lastY = ev.clientY;
    };
    state.onUp = function () {
      if (!state.dragging) return;
      state.dragging = false;
      if (!state.focus) {
        clearTimeout(state.dragIdleTimer);
        state.dragIdleTimer = setTimeout(function () { state.spinning = true; }, 2500);
        state.spinning = false;
      }
    };
    window.addEventListener('pointermove', state.onMove);
    window.addEventListener('pointerup', state.onUp);

    function hitDot(ev) {
      var rect = canvas.getBoundingClientRect();
      var x = ev.clientX - rect.left, y = ev.clientY - rect.top;
      var best = null, bestD = 1e9;
      for (var i = 0; i < state.dotHits.length; i++) {
        var d = state.dotHits[i];
        var dist = Math.hypot(d.x - x, d.y - y);
        if (dist <= d.r && dist < bestD) { best = d; bestD = dist; }
      }
      return best;
    }
    canvas.addEventListener('mousemove', function (ev) {
      var hit = hitDot(ev);
      if (hit) {
        var seg = V.segByKey(hit.city.seg);
        V.tip.show('<b>' + V.fmt.esc(hit.city.entity) + '</b><div class="tip-sub">' +
          V.fmt.esc(hit.city.city) + ', ' + V.fmt.esc(countryName[hit.city.country] || hit.city.country) +
          ' &middot; ' + (seg ? seg.label : hit.city.seg) +
          '<br>metro GDP ' + fmtB(hit.city.gdp) + ' (compiled) &middot; influence est. ' + fmtB(influence(hit.city)) + ' (modeled)</div>', ev.clientX, ev.clientY);
        canvas.style.cursor = 'pointer';
      } else {
        V.tip.hide();
        canvas.style.cursor = 'grab';
      }
    });
    canvas.addEventListener('mouseleave', V.tip.hide);
    canvas.addEventListener('click', function (ev) {
      var hit = hitDot(ev);
      if (hit) {
        var seg = V.segByKey(hit.city.seg);
        status.textContent = hit.city.entity + ' | ' + hit.city.city + ', ' +
          (countryName[hit.city.country] || hit.city.country) + ' | ' + (seg ? seg.label : hit.city.seg) +
          ' | metro GDP ' + fmtB(hit.city.gdp) + ' | influence est. ' + fmtB(influence(hit.city));
      }
    });

    /* test and debug hook */
    V.globe.debug = function () {
      var top = data.cities.slice().sort(function (a, b) { return influence(b) - influence(a); })[0];
      return {
        dots: data.cities.length,
        countries: data.countries.length,
        focus: state.focus,
        spinning: state.spinning,
        zoom: state.zoom,
        center: [state.cLng, state.cLat],
        gdpTotal: data.cities.reduce(function (s, c) { return s + (c.gdp || 0); }, 0),
        topInfluence: top ? top.entity : null
      };
    };
    V.globe.focusCountry = focusCountry;

    renderCityPanel(null);
    state.raf = requestAnimationFrame(tick);
  };
})(window.V);
