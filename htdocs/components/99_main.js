// $Revision$

// Stop console commands causing problems
if (!('console' in window)) {
  (function () {
    var names = [ 'log','debug','info','warn','error','assert','dir','dirxml','group','groupEnd','time','timeEnd','count','trace','profile','profileEnd' ];
    window.console = {};
    
    for (var i = 0; i < names.length; i++) {
      window.console[names[i]] = $.noop;
    }
  })();
} else {
  (function () {
    if (!window.console.time) {
      window._timerCache = {};
      
      window.console.time = function (key) {
        window._timerCache[key] = new Date().getTime();
      };
      
      window.console.timeEnd = function (key) {
        console.log(key + ': ' + (new Date().getTime() - window._timerCache[key]) + 'ms');
        delete window._timerCache[key];
      }
    }
  })();
}

// Interface between old and new javascript models - old plugins will still work
window.addLoadEvent = function (func) {
  Ensembl.extend({
    initialize: function () {
      this.base();
      func();
    }
  });
};

$(function () {
  if (!window.JSON) {
    $.getScript('/components/json2.js', function () { Ensembl.initialize(); });
  } else {
    Ensembl.initialize();
  }
});
