// $Revision$

// Stop console commands causing problems
if (!('console' in window) || !('firebug' in console)) {
  (function () {
    var names = [ 'log','debug','info','warn','error','assert','dir','dirxml','group','groupEnd','time','timeEnd','count','trace','profile','profileEnd' ];
    window.console = {};
    
    for (var i = 0; i < names.length; i++) {
      window.console[names[i]] = function () {};
    }
  })();
}

// Interface between old and new javascript models - old plugins will still work
function addLoadEvent(func) {
  Ensembl.extend({
    initialize: function () {
      this.base();
      func();
    }
  });
}

$(function () {
  Ensembl.initialize();
});
