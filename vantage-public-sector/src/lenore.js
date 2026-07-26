/* VANTAGE Public Sector Edition: Lenore generation panel.
   Lenore is the Marsh internal AI portal. This panel offers a model
   selector and generates outreach copy for the open entity. With no
   credential present it uses a deterministic offline fallback and says
   so plainly. No API keys live anywhere in this source. */

window.V = window.V || {};

(function (V) {
  'use strict';

  V.lenore = {};

  var MODELS = [
    { id: 'lenore-fast', label: 'Lenore Fast (short drafts)' },
    { id: 'lenore-standard', label: 'Lenore Standard' },
    { id: 'lenore-deep', label: 'Lenore Deep (long-form research)' }
  ];

  /* Session-only: never persisted, never written into source or bundle. */
  var sessionCredential = '';
  var selectedModel = MODELS[1].id;

  V.lenore.renderPanel = function (body, e) {
    body.innerHTML =
      '<div class="lenore-panel">' +
      '<label class="auth-label" style="text-align:left;margin:0">Lenore model</label>' +
      '<select id="lenore-model">' + MODELS.map(function (m) {
        return '<option value="' + m.id + '"' + (m.id === selectedModel ? ' selected' : '') + '>' + m.label + '</option>';
      }).join('') + '</select>' +
      '<label class="auth-label" style="text-align:left;margin:0">Lenore credential (session only, optional)</label>' +
      '<input id="lenore-cred" type="password" autocomplete="off" placeholder="Paste a Lenore portal credential to go online" value="' + V.fmt.esc(sessionCredential) + '">' +
      '<div class="lenore-status" id="lenore-status"></div>' +
      '<div><button class="btn" id="lenore-generate">Generate outreach</button></div>' +
      '<div class="lenore-out" id="lenore-out">Output appears here.</div>' +
      '</div>';

    var statusEl = document.getElementById('lenore-status');
    var credEl = document.getElementById('lenore-cred');
    var updateStatus = function () {
      if (credEl.value.trim()) {
        statusEl.className = 'lenore-status';
        statusEl.textContent = 'Credential present for this session. Requests go to the Lenore portal if one is configured.';
      } else {
        statusEl.className = 'lenore-status offline';
        statusEl.textContent = 'Offline fallback active: no Lenore credential present. Output below is template-generated locally.';
      }
    };
    updateStatus();

    credEl.addEventListener('input', function () {
      sessionCredential = credEl.value;
      updateStatus();
    });
    document.getElementById('lenore-model').addEventListener('change', function (ev) {
      selectedModel = ev.target.value;
    });
    document.getElementById('lenore-generate').addEventListener('click', function () {
      var out = document.getElementById('lenore-out');
      if (sessionCredential.trim() && window.LENORE_ENDPOINT) {
        out.textContent = 'Contacting Lenore (' + selectedModel + ')...';
        V.lenore.callPortal(e, selectedModel, sessionCredential).then(function (text) {
          out.textContent = text;
        }).catch(function (err) {
          out.textContent = 'Lenore request failed (' + err.message + ').\n\nFalling back to the offline template:\n\n' + V.lenore.offlineDraft(e, selectedModel);
        });
      } else {
        out.textContent = V.lenore.offlineDraft(e, selectedModel) +
          '\n\n[Offline fallback: generated locally without Lenore. Model selection (' + selectedModel + ') applies once a credential and portal endpoint are configured.]';
      }
    });
  };

  /* Deployment hook: an environment that fronts the Lenore portal sets
     window.LENORE_ENDPOINT at runtime. Nothing is baked into the bundle. */
  V.lenore.callPortal = function (e, model, credential) {
    return fetch(window.LENORE_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + credential },
      body: JSON.stringify({ model: model, entity: e.id, task: 'outreach' })
    }).then(function (r) {
      if (!r.ok) throw new Error('portal returned ' + r.status);
      return r.json();
    }).then(function (j) { return j.text || JSON.stringify(j); });
  };

  V.lenore.offlineDraft = function (e, model) {
    var seg = V.segByKey(e.seg);
    var status = V.verifStatus(e);
    var noRecord = status === 'no-record';
    var lines = [];
    lines.push('SUBJECT: ' + e.name + ': property program review ahead of renewal [MODELED DATE: ' + e.renew + ']');
    lines.push('');
    lines.push('Hi [CONTACT NAME],');
    lines.push('');
    lines.push('I lead public entity property placements at Marsh in our Public Entity and Education practice. ' +
      'We have been mapping ' + seg.label.toLowerCase() + ' exposures and ' + e.name + ' stands out: ' +
      'roughly ' + V.fmt.money(e.tiv) + ' in insured values (our derived estimate) against an estimated ' +
      V.fmt.money(e.prem) + ' annual property spend.');
    lines.push('');
    if (noRecord) {
      lines.push('One specific gap we can close quickly: our verification sweep found no public floor record for ' +
        e.site + '. If the floor count is missing from public data, it is often stale on the schedule of values too, ' +
        'and that is exactly the kind of gap that surfaces at claim time. We would start there.');
    } else {
      lines.push('Our verification sweep shows ' + e.site + ' with ' + e.floors + ' floors on record. ' +
        'We would pressure-test the rest of the schedule of values against observed reality before any quote.');
    }
    lines.push('');
    lines.push('Conversation opener on file [MODELED]: ' + e.trigger);
    lines.push('Incumbent on file [MODELED]: ' + e.inc);
    lines.push('');
    lines.push('Would 20 minutes in the next two weeks work to walk through the property intelligence we have assembled for ' + e.city + '?');
    lines.push('');
    lines.push('Best regards,');
    lines.push(V.state.user ? V.state.user.name : '[PRODUCER]');
    lines.push('Marsh, Public Entity and Education');
    return lines.join('\n');
  };
})(window.V);
