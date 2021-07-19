/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2021] EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
