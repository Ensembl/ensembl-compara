/*
 * Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
  $.fn.newtable_decorate_link = function(config,data) {
    function decorate_fn(column,extras,series) {
      var rseries = {};
      $.each(series,function(i,v) { rseries[v] = i; });

      return function(html,row) {
        var base = extras['*'].base_url;
        var params = (extras['*'].params || {});
        var extra = [];
        var ok = true;
        for(var k in params) {
          if(!params.hasOwnProperty(k)) { continue; }
          var v = params[k];
          var val = row[rseries[v]];
          if(val===null || val===undefined) {
            ok = false;
          } else {
            extra.push(k+'='+encodeURIComponent(row[rseries[v]]));
          }
        }
        if(!ok) { return html; }
        var rest = '';
        if(extra.length) {
          if(base.match(/\?/)) { rest = ';'; } else { rest = '?'; }
        }
        rest = rest + extra.join(';');
        if(extras['*'] && extras['*'].base_url) {
          if(html.match(/<a/)) {
            html = html.replace(/href="/g,'href="'+base+rest);
          } else {
            html = '<a href="'+base+rest+'">'+html+'</a>';
          }
        }
        return html;
      };
    }

    var decorators = {};
    $.each(config.colconf,function(key,cc) {
      if(cc.decorate && cc.decorate == "link") {
        decorators[key] = [decorate_fn];
      }
    });

    return {
      decorators: {
        link: decorators
      }
    };
  }; 

})(jQuery);
