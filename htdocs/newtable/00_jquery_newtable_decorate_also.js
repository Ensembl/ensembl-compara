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

(function($) {
  $.fn.newtable_decorate_also = function(config,data) {
    function decorate_fn(column,extras,series) {
      var rseries = {};
      $.each(series,function(i,v) { rseries[v] = i; });
      return {
        go: function(html,row) {
          var cols = (extras['*'].cols || []);
          var extra = [];
          var ok = true;
          for(var i=0;i<cols.length;i++) {
            var v = cols[i];
            var val = row[rseries[v]];
            if(val===null || val===undefined) {
              ok = false;
            } else {
              extra.push('<small>('+row[rseries[v]]+')</small>');
            }
          }
          if(!ok) { return html; }
          return html + ' ' + extra.join(' ');
        }
      };
    }

    var decorators = {};
    $.each(config.colconf,function(key,cc) {
      if(cc.decorate && $.inArray("also",cc.decorate)!=-1) {
        decorators[key] = [decorate_fn];
      }
    });

    return {
      decorators: {
        also: decorators
      }
    };
  }; 

})(jQuery);
