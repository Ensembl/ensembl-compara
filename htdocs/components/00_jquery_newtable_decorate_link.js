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
        if (!extras['*'] || !extras['*'].base_url) {
          return html;
        }
        var url = extras['*'].base_url;
        var params = (extras['*'].params || {});
        var extra = url.match(/\?/) ? (function () {
          var p = {};
          $.each(url.split('?')[1].split(/\;|\&/), function (i,v) { v = v.split('='); p[v[0]] = v[1]; });
          return p;
        })(url) : {};
        var ok = true;
        for(var k in params) {
          if(!params.hasOwnProperty(k)) { continue; }
          var v = params[k];
          var val = params[k] ? row[rseries[v]] : false;
          if(val===null || val===undefined) {
            ok = false;
          } else {
            if (val === false) {
              delete extra[k];
            } else {
              extra[k] = encodeURIComponent(val);
            }
          }
        }
        if(!ok) { return html; }
        url = (function(base, params) {
          params = $.map(params, function(v,i) { return i + '=' + v }).sort().join(';');
          return params ? base + '?' + params : base;
        })(url.split(/\?/)[0], extra);

        if(html.match(/<a/)) {
          html = html.replace(/href="/g,'href="'+url);
        } else {
          html = '<a href="'+url+'">'+html+'</a>';
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
