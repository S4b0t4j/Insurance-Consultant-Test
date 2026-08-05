/* VANTAGE Public Sector Edition: structure massing viewer.
   Renders one visible band per floor on record using three.js (r128).
   Falls back to a 2D SVG elevation when WebGL or three.js is unavailable.
   An entity with no floor record gets an explicit empty state, never a
   guessed massing. */

window.V = window.V || {};

(function (V) {
  'use strict';

  V.viewer3d = {};

  var active = null; /* {raf, renderer, container, onDown, onMove, onUp} */

  V.viewer3d.webglAvailable = function () {
    try {
      var canvas = document.createElement('canvas');
      var gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
      return !!(gl && typeof gl.getParameter === 'function');
    } catch (e) {
      return false;
    }
  };

  V.viewer3d.unmount = function () {
    if (!active) return;
    if (active.raf) cancelAnimationFrame(active.raf);
    if (active.renderer) {
      try {
        active.renderer.dispose();
        active.renderer.forceContextLoss();
      } catch (e) { /* context already gone */ }
    }
    if (active.container) {
      active.container.removeEventListener('pointerdown', active.onDown);
      window.removeEventListener('pointermove', active.onMove);
      window.removeEventListener('pointerup', active.onUp);
    }
    active = null;
  };

  /* Mount the viewer for an entity into a container element.
     Returns a string describing which mode rendered: '3d', 'svg', 'empty'. */
  V.viewer3d.mount = function (container, entity) {
    V.viewer3d.unmount();
    var status = V.verifStatus(entity);

    if (entity.floors === null || status === 'no-record') {
      renderEmpty(container, entity);
      return 'empty';
    }
    if (window.THREE && V.viewer3d.webglAvailable()) {
      try {
        render3d(container, entity);
        return '3d';
      } catch (e) {
        /* a WebGL context can still fail at creation time */
        renderSvg(container, entity);
        return 'svg';
      }
    }
    renderSvg(container, entity);
    return 'svg';
  };

  function renderEmpty(container, entity) {
    container.innerHTML =
      '<div class="viewer-empty">' +
      '<div class="empty-flag">NO FLOOR RECORD</div>' +
      '<div class="empty-body">' + V.fmt.esc(entity.site) + ' has no public floor count. ' +
      'VANTAGE will not guess a massing. This structure sits at the top of the ' +
      'Verification Queue until the schedule of values is confirmed on site.</div>' +
      '</div>';
  }

  function accentFor(entity) {
    var seg = V.segByKey(entity.seg);
    return seg ? seg.accent : '#04B4BF';
  }

  /* ---------- three.js massing: one box band per floor ---------- */

  function render3d(container, entity) {
    var THREE = window.THREE;
    var w = container.clientWidth || 500;
    var h = container.clientHeight || 260;
    var floors = entity.floors;

    var renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(w, h);
    container.innerHTML = '';
    container.appendChild(renderer.domElement);

    var scene = new THREE.Scene();
    var camera = new THREE.PerspectiveCamera(38, w / h, 0.1, 1000);

    var floorH = 1;
    var gap = 0.16;
    var side = Math.max(6, Math.min(14, floors * 0.55));
    var totalH = floors * (floorH + gap);

    var accent = new THREE.Color(accentFor(entity));
    var base = new THREE.Color('#0C3348');
    var group = new THREE.Group();

    for (var i = 0; i < floors; i++) {
      var geom = new THREE.BoxGeometry(side, floorH, side * 0.72);
      var isBand = i % 5 === 4;
      var mat = new THREE.MeshLambertMaterial({ color: isBand ? accent : base });
      var box = new THREE.Mesh(geom, mat);
      box.position.y = i * (floorH + gap) + floorH / 2;
      group.add(box);
      var edges = new THREE.LineSegments(
        new THREE.EdgesGeometry(geom),
        new THREE.LineBasicMaterial({ color: isBand ? 0xffbf00 : 0x2a5068 })
      );
      edges.position.copy(box.position);
      group.add(edges);
    }

    /* ground plate */
    var plate = new THREE.Mesh(
      new THREE.BoxGeometry(side * 2.2, 0.12, side * 1.8),
      new THREE.MeshLambertMaterial({ color: 0x00263a })
    );
    plate.position.y = -0.12;
    group.add(plate);

    group.position.y = -totalH / 2;
    scene.add(group);

    scene.add(new THREE.AmbientLight(0xceecff, 0.55));
    var key = new THREE.DirectionalLight(0xffffff, 0.85);
    key.position.set(18, 26, 22);
    scene.add(key);

    var dist = Math.max(totalH * 1.35, side * 3.1);
    camera.position.set(dist, totalH * 0.35, dist);
    camera.lookAt(0, 0, 0);

    var rotY = 0.7, rotX = 0.0, dragging = false, lastX = 0, lastY = 0;
    var onDown = function (ev) { dragging = true; lastX = ev.clientX; lastY = ev.clientY; };
    var onMove = function (ev) {
      if (!dragging) return;
      rotY += (ev.clientX - lastX) * 0.008;
      rotX = Math.max(-0.5, Math.min(0.5, rotX + (ev.clientY - lastY) * 0.004));
      lastX = ev.clientX; lastY = ev.clientY;
    };
    var onUp = function () { dragging = false; };
    container.addEventListener('pointerdown', onDown);
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);

    var state = { raf: 0, renderer: renderer, container: container, onDown: onDown, onMove: onMove, onUp: onUp };
    active = state;

    (function loop() {
      if (active !== state) return;
      if (!dragging) rotY += 0.004;
      group.rotation.y = rotY;
      group.rotation.x = rotX;
      renderer.render(scene, camera);
      state.raf = requestAnimationFrame(loop);
    })();
  }

  /* ---------- SVG elevation fallback: one rect band per floor ---------- */

  function renderSvg(container, entity) {
    var floors = entity.floors;
    var W = 460, H = 250;
    var pad = 24;
    var bandGap = 2;
    var availH = H - pad * 2 - 14;
    var bandH = Math.max(2, (availH - bandGap * (floors - 1)) / floors);
    var bw = Math.max(90, Math.min(200, 60 + floors * 3));
    var x0 = (W - bw) / 2;
    var accent = accentFor(entity);

    var parts = ['<svg viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="2D elevation: one band per floor on record">'];
    for (var i = 0; i < floors; i++) {
      var y = H - pad - 14 - (i + 1) * bandH - i * bandGap;
      var isBand = i % 5 === 4;
      parts.push('<rect x="' + x0 + '" y="' + y.toFixed(1) + '" width="' + bw + '" height="' + bandH.toFixed(1) + '" fill="' + (isBand ? accent : '#0C3348') + '" stroke="' + (isBand ? '#FFBF00' : '#2A5068') + '" stroke-width="0.8"/>');
    }
    parts.push('<line x1="' + (pad * 2) + '" y1="' + (H - pad - 13) + '" x2="' + (W - pad * 2) + '" y2="' + (H - pad - 13) + '" stroke="#4A6B7C" stroke-width="1.5"/>');
    parts.push('<text x="' + (W / 2) + '" y="' + (H - pad + 10) + '" text-anchor="middle" fill="#9FB4C2" font-size="10">' +
      floors + ' floors on record &middot; 2D elevation fallback (WebGL unavailable)</text>');
    parts.push('</svg>');
    container.innerHTML = parts.join('');
  }
})(window.V);
