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
  function expand_urls(urls_in,texts_in,titles_in,extras,more) {
    var urls = [urls_in];
    var texts = [texts_in];
    var titles = [titles_in];
    if((urls_in||'').charAt(0) == '\r') {
      urls = urls_in.substring(1).split('\r');
      texts = texts_in.substring(1).split('\r');
    }
    if((titles_in||'').charAt(0) == '\r') {
      titles = titles_in.substring(1).split('\r');
    }
    html = "";

    for(var i=0;i<texts.length;i++) {
      if(i) { html += ', '; }
      var here = texts[i];
      var title = '';
      var more_here = more;
      if(i<titles.length) { more_here += ' title="'+titles[i]+'"'; }
      if(urls[i]) { here = '<a href="'+urls[i]+'"'+more_here+'>'+here+'</a>'; }
      html += here;
    }
    if(extras) {
      html += '<br /><span class="small" style="white-space:nowrap;"><b>ID: </b>'+extras+'</span>';
    }
    return html;
  }

  $.fn.newtable_decorate_link = function(config,data) {
    function decorate_fn(column,extras,series) {
      var rseries = {};
      $.each(series,function(i,v) { rseries[v] = i; });

      if (extras['*'] && extras['*'].base_url) {
        if (extras['*'].base_url.match(/\?/)) {
          extras['*'].query = (function (url) {
            var p = {};
            $.each(url.split('?')[1].split(/\;|\&/), function (i,v) { v = v.split('='); p[v[0]] = v[1]; });
            return p;
          })(extras['*'].base_url);
          extras['*'].base_url = extras['*'].base_url.split(/\?/)[0];
        }
      }

      return {
        go: function(html,row) {
          if (extras['*']) {
            var more = '';
            if(extras['*'].url_rel) {
              more = ' rel="'+extras['*'].url_rel+'"';
            }
            if(extras['*'].url_column) {
              var titles = '';
              if(extras['*'].title_column) {
                titles = row[rseries[extras['*'].title_column]];
              }
              var extra = '';
              if(extras['*'].extra_column) {
                extra = row[rseries[extras['*'].extra_column]];
              }
              var url = row[rseries[extras['*'].url_column]];
              html = expand_urls(url,html,titles,extra,more);
            } else if(extras['*'].base_url) {
              var url = extras['*'].base_url;
              var params = extras['*'].params || {};
              var query = extras['*'].query || {};
              var ok = true;
              for(var k in params) {
                if(!params.hasOwnProperty(k)) { continue; }
                var v = params[k];
                var val = params[k] ? row[rseries[v]] : false;
                if(val===null || val===undefined) {
                  ok = false;
                } else {
                  if (val === false) {
                    delete query[k];
                  } else {
                    query[k] = encodeURIComponent(val);
                  }
                }
              }
              if(!ok) { return html; }
              url = (function(base, params) {
                params = $.map(params, function(v,i) { return i + '=' + v }).sort().join(';');
                return params ? base + '?' + params : base;
              })(url, query);
  
              if(html.match(/<a/)) {
                html = html.replace(/href="/g,'href="'+url);
              } else {
                html = '<a href="'+url+'"'+more+'>'+html+'</a>';
              }
            }
          }
          return html;
        }
      };
    }

    var decorators = {};
    $.each(config.colconf,function(key,cc) {
      if(cc.decorate && $.inArray("link",cc.decorate)!=-1) {
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
