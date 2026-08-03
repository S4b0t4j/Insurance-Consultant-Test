/* VANTAGE Public Sector Edition: role chooser and producer confirmation.
   No access code: the dashboard already sits behind the app login and
   Cloudflare Access, so a fourth gate here only cost clicks. Pick
   Administrator to go straight in, or pick a producer and confirm by
   typing their last name. That last-name check still stands, because it
   scopes the session to that producer's own accounts. */

window.V = window.V || {};

(function (V) {
  'use strict';

  var authRoot = function () { return document.getElementById('auth-screen'); };

  V.auth = {};

  V.auth.renderLogin = function () {
    var el = authRoot();
    el.hidden = false;
    document.getElementById('app-shell').hidden = true;
    el.innerHTML =
      '<div class="auth-card" id="auth-card">' +
      brand() +
      '<div class="auth-label">How are you viewing today?</div>' +
      '<button class="roster-btn" id="enter-admin" type="button">Continue as Administrator' +
      '<span class="roster-territory">Full portfolio across all territories</span></button>' +
      '<button class="roster-btn" id="enter-producer" type="button">Sign in as a producer' +
      '<span class="roster-territory">See only your own accounts</span></button>' +
      '<div class="auth-error" id="auth-error"></div>' +
      '</div>';
    document.getElementById('enter-admin').addEventListener('click', function () {
      V.auth.start({ role: 'admin', name: 'Administrator', producerKey: null });
    });
    document.getElementById('enter-producer')
      .addEventListener('click', V.auth.renderRoster);
  };

  V.auth.renderRoster = function () {
    var el = authRoot();
    el.innerHTML =
      '<div class="auth-card" id="auth-card">' +
      brand() +
      '<div class="auth-label">Producer access. Select your name.<br>' +
      '<span style="color:var(--gold)">Mock roster: producer names are demonstration placeholders, not real people.</span></div>' +
      '<div class="roster">' +
      V.state.data.producers.map(function (p) {
        return '<button class="roster-btn" data-key="' + p.key + '">' + V.fmt.esc(p.name) +
          '<span class="roster-territory">' + V.fmt.esc(p.territory) + '</span></button>';
      }).join('') +
      '</div>' +
      '<div style="margin-top:14px"><button class="btn btn-ghost btn-sm" id="roster-back">Back</button></div>' +
      '</div>';
    document.getElementById('roster-back').addEventListener('click', V.auth.renderLogin);
    Array.prototype.forEach.call(el.querySelectorAll('.roster-btn'), function (btn) {
      btn.addEventListener('click', function () {
        V.auth.renderConfirm(btn.getAttribute('data-key'));
      });
    });
  };

  V.auth.renderConfirm = function (producerKey) {
    var producer = null;
    V.state.data.producers.forEach(function (p) { if (p.key === producerKey) producer = p; });
    if (!producer) return V.auth.renderRoster();
    var el = authRoot();
    el.innerHTML =
      '<div class="auth-card" id="auth-card">' +
      brand() +
      '<div class="auth-label">Confirm identity for <b style="color:var(--sky)">' + V.fmt.esc(producer.name) + '</b><br>Type your last name.</div>' +
      '<input class="text-input" id="lastname-input" type="text" autocomplete="off" aria-label="Last name" style="text-align:center">' +
      '<div class="auth-error" id="auth-error"></div>' +
      '<div style="display:flex;gap:9px;justify-content:center;margin-top:6px">' +
      '<button class="btn" id="confirm-btn">Confirm</button>' +
      '<button class="btn btn-ghost" id="confirm-back">Back</button>' +
      '</div></div>';
    var input = document.getElementById('lastname-input');
    input.focus();
    var submit = function () {
      if (input.value.trim().toLowerCase() === producer.lastName.toLowerCase()) {
        V.auth.start({ role: 'producer', name: producer.name, producerKey: producer.key });
      } else {
        input.value = '';
        showError('Last name does not match the roster');
      }
    };
    document.getElementById('confirm-btn').addEventListener('click', submit);
    input.addEventListener('keydown', function (ev) { if (ev.key === 'Enter') submit(); });
    document.getElementById('confirm-back').addEventListener('click', V.auth.renderRoster);
  };

  V.auth.start = function (user) {
    V.state.user = user;
    V.state.view = 'map';
    V.state.selectedState = null;
    V.state.selectedSeg = null;
    V.state.drawerId = null;
    authRoot().hidden = true;
    document.getElementById('app-shell').hidden = false;
    V.renderShell();
  };

  V.auth.logout = function () {
    V.state.user = null;
    V.drawer.close();
    V.auth.renderLogin();
  };

  function brand() {
    return '<h1 class="brand-word">VANTA<span class="brand-tail">GE</span></h1>' +
      '<div class="brand-sub">Public Sector</div>';
  }

  function showError(msg) {
    var err = document.getElementById('auth-error');
    if (err) err.textContent = msg;
    var card = document.getElementById('auth-card');
    if (card) {
      card.classList.remove('auth-shake');
      void card.offsetWidth;
      card.classList.add('auth-shake');
    }
  }
})(window.V);
