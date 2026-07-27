/* VANTAGE Public Sector Edition: role scoping and filter logic.
   Producers see only their own accounts. Admin sees everything.
   All views pull entities through this module; nothing reads the raw
   entity list directly. */

window.V = window.V || {};

(function (V) {
  'use strict';

  V.scope = {};

  /* Entities visible to the signed-in user, before view filters. */
  V.scope.entities = function () {
    var all = V.state.data.entities;
    var user = V.state.user;
    if (!user) return [];
    if (user.role === 'admin') return all.slice();
    return all.filter(function (e) { return e.producer === user.producerKey; });
  };

  /* Entities after the map view filters (state and segment selection). */
  V.scope.filtered = function () {
    var list = V.scope.entities();
    if (V.state.selectedState) {
      list = list.filter(function (e) { return e.state === V.state.selectedState; });
    }
    if (V.state.selectedSeg) {
      list = list.filter(function (e) { return e.seg === V.state.selectedSeg; });
    }
    return list;
  };

  /* States inside the user's scope (admin: all states). */
  V.scope.states = function () {
    if (V.state.user && V.state.user.role === 'producer') {
      var producer = null;
      V.state.data.producers.forEach(function (p) {
        if (p.key === V.state.user.producerKey) producer = p;
      });
      if (producer) return producer.states.slice();
    }
    return Object.keys(V.state.data.gdp);
  };

  /* Premium pool: POOL_BPS applied to nominal GDP of in-scope states. */
  V.scope.premiumPool = function () {
    var gdp = V.state.data.gdp;
    var sum = 0;
    V.scope.states().forEach(function (st) { sum += gdp[st] || 0; });
    /* gdp is in billions of USD; bps of that in USD */
    return sum * 1e9 * (V.state.poolBps / 10000);
  };

  /* Opportunity density per state: in-scope entity TIV per billion GDP.
     Used to shade the market cartogram. */
  V.scope.densityByState = function () {
    var density = {};
    var tivByState = {};
    V.scope.entities().forEach(function (e) {
      tivByState[e.state] = (tivByState[e.state] || 0) + e.tiv;
    });
    var gdp = V.state.data.gdp;
    Object.keys(gdp).forEach(function (st) {
      density[st] = (tivByState[st] || 0) / (gdp[st] * 1e9);
    });
    return density;
  };

  V.scope.countByState = function () {
    var counts = {};
    V.scope.entities().forEach(function (e) {
      counts[e.state] = (counts[e.state] || 0) + 1;
    });
    return counts;
  };
})(window.V);
