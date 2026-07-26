/* VANTAGE Public Sector Edition: Market view.
   Squarified treemap where tile area is state nominal GDP, grouped by
   BEA region, shaded by public sector opportunity density (in-scope
   entity TIV per billion of state GDP). */

window.V = window.V || {};

(function (V) {
  'use strict';

  V.cartogram = {};

  /* Classic squarify (Bruls, Huizing, van Wijk). items: [{key, value}].
     Returns [{key, value, x, y, w, h}]. */
  function squarify(items, x, y, w, h) {
    var out = [];
    var list = items.slice().sort(function (a, b) { return b.value - a.value; });
    var total = list.reduce(function (s, d) { return s + d.value; }, 0);
    if (total <= 0 || w <= 0 || h <= 0) return out;
    var scale = (w * h) / total;

    var i = 0;
    while (i < list.length) {
      var row = [];
      var rowSum = 0;
      var short = Math.min(w, h);
      var worst = Infinity;
      var j = i;
      while (j < list.length) {
        var area = list[j].value * scale;
        var testSum = rowSum + area;
        var rowLen = testSum / short;
        var worstNow = 0;
        for (var k = i; k <= j; k++) {
          var a = list[k].value * scale;
          var side = a / rowLen;
          worstNow = Math.max(worstNow, rowLen / side, side / rowLen);
        }
        /* also account for the candidate itself via aspect of its cell */
        if (worstNow > worst) break;
        worst = worstNow;
        row.push(list[j]);
        rowSum = testSum;
        j++;
      }
      var len = rowSum / short;
      var offset = 0;
      for (var m = 0; m < row.length; m++) {
        var cellArea = row[m].value * scale;
        var cellSide = cellArea / len;
        if (w >= h) {
          out.push({ key: row[m].key, value: row[m].value, ref: row[m], x: x, y: y + offset, w: len, h: cellSide });
        } else {
          out.push({ key: row[m].key, value: row[m].value, ref: row[m], x: x + offset, y: y, w: cellSide, h: len });
        }
        offset += cellSide;
      }
      if (w >= h) { x += len; w -= len; } else { y += len; h -= len; }
      i = j;
    }
    return out;
  }

  /* Density shading between CARD_BG and ACTIVE_BLUE, GOLD at the top end. */
  function shade(t) {
    /* t in [0, 1] */
    var from = [12, 51, 72];      /* #0C3348 */
    var mid = [4, 180, 191];      /* #04B4BF */
    var to = [255, 191, 0];       /* #FFBF00 */
    var a, b, u;
    if (t < 0.75) { a = from; b = mid; u = t / 0.75; }
    else { a = mid; b = to; u = (t - 0.75) / 0.25; }
    var c = a.map(function (v, i) { return Math.round(v + (b[i] - v) * u); });
    return 'rgb(' + c.join(',') + ')';
  }

  V.cartogram.render = function (container) {
    var W = 940, H = 560, PAD = 3, REGION_HEAD = 14;
    var gdp = V.state.data.gdp;
    var regions = V.state.data.regions;
    var names = V.state.data.stateNames;
    var density = V.scope.densityByState();
    var counts = V.scope.countByState();

    var maxDensity = 0;
    Object.keys(density).forEach(function (st) { maxDensity = Math.max(maxDensity, density[st]); });

    var regionItems = Object.keys(regions).map(function (name) {
      var value = regions[name].reduce(function (s, st) { return s + gdp[st]; }, 0);
      return { key: name, value: value };
    });

    var regionRects = squarify(regionItems, 0, 0, W, H);
    var svg = [
      '<svg viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="Market cartogram: state tiles sized by nominal GDP">'
    ];

    regionRects.forEach(function (rr) {
      svg.push('<rect x="' + rr.x + '" y="' + rr.y + '" width="' + rr.w + '" height="' + rr.h + '" fill="none" stroke="#2A5068" stroke-width="2"/>');
      if (rr.w > 76 && rr.h > 30) {
        svg.push('<text class="region-label" x="' + (rr.x + 6) + '" y="' + (rr.y + 11) + '">' + rr.key + '</text>');
      }
      var stateItems = regions[rr.key].map(function (st) { return { key: st, value: gdp[st] }; });
      var inner = squarify(stateItems, rr.x + PAD, rr.y + PAD + (rr.w > 76 && rr.h > 30 ? REGION_HEAD : 0), rr.w - PAD * 2, rr.h - PAD * 2 - (rr.w > 76 && rr.h > 30 ? REGION_HEAD : 0));
      inner.forEach(function (cell) {
        var st = cell.key;
        var t = maxDensity > 0 ? density[st] / maxDensity : 0;
        var selected = V.state.selectedState === st;
        svg.push('<rect class="tile' + (selected ? ' selected' : '') + '" data-state="' + st + '" x="' + cell.x + '" y="' + cell.y + '" width="' + Math.max(0, cell.w - 1) + '" height="' + Math.max(0, cell.h - 1) + '" fill="' + shade(t) + '"/>');
        if (cell.w > 34 && cell.h > 20) {
          var cx = cell.x + cell.w / 2;
          var cy = cell.y + cell.h / 2;
          var dark = t > 0.55;
          svg.push('<text class="tile-label" x="' + cx + '" y="' + cy + '" text-anchor="middle" font-size="' + Math.min(16, Math.max(10, cell.w / 5)) + '"' + (dark ? ' fill="#00263A"' : '') + '>' + st + '</text>');
          if (cell.h > 44) {
            svg.push('<text class="tile-sub" x="' + cx + '" y="' + (cy + 14) + '" text-anchor="middle" font-size="9"' + (dark ? ' fill="#0C3348"' : '') + '>' + (counts[st] || 0) + ' acct</text>');
          }
        }
      });
    });

    svg.push('</svg>');
    container.innerHTML = svg.join('');

    var pool = V.state.poolBps;
    Array.prototype.forEach.call(container.querySelectorAll('.tile'), function (rect) {
      var st = rect.getAttribute('data-state');
      rect.addEventListener('click', function () {
        V.state.selectedState = V.state.selectedState === st ? null : st;
        V.renderShell();
      });
      rect.addEventListener('mousemove', function (ev) {
        var statePool = gdp[st] * 1e9 * (pool / 10000);
        V.tip.show(
          '<b>' + names[st] + '</b><div class="tip-sub">GDP $' + V.fmt.int(gdp[st]) + 'B &middot; ' +
          (counts[st] || 0) + ' accounts in scope<br>Est. premium pool at ' + pool + ' bps: ' + V.fmt.money(statePool) + '</div>',
          ev.clientX, ev.clientY);
      });
      rect.addEventListener('mouseleave', V.tip.hide);
    });
  };
})(window.V);
