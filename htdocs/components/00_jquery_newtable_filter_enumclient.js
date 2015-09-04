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
  function is_number(x) {
    try { return !isNaN(parseFloat(x)); } catch(error) { return false; }
  }

  function html_cleaned(x) {
    x = x.replace(/<[^>]*? class="[^"]*?hidden.*?<\/.*?>/g,'');
    x = x.replace(/<.*?>/g,'');
    x = x.replace(/\&.*?;/g,'');
    return x;
  }

  function html_hidden(x) {
    var m = x.match(/<span class="hidden">(.*?)<\/span>/);
    if(m) { return m[1]; }
    return x;
  }

  function number_clean(x) {
    return x.replace(/([\d\.e\+-])\s.*$/,'$1');
  }

  function minmax(vv,v) {
    if(!is_number(v)) { return; }
    if(vv.hasOwnProperty('min')) {
      vv.min = vv.min<v?vv.min:v;
      vv.max = vv.max>v?vv.max:v;
    } else {
      vv.min = vv.max = v;
    }
  }

  function split_top_level(all) {
    var seq = [];
    while(true) {
      var m = /<\/?div.*?>/.exec(all);
      if(m===null) {
        seq.push(all);
        break;
      } else {
        seq.push(all.substring(0,m.index));
        all = all.substring(m.index);
        seq.push(all.substring(0,m[0].length));
        all = all.substring(m[0].length);
      }
    }
    var count = 0;
    var out = [];
    for(var i=0;i<seq.length;i++) {
      if(seq[i].match(/<div/)) {
        count++;
        if(count==1) { out.push(""); continue; }
      } else if(seq[i].match(/<\/div/)) {
        count--;
        if(!count) { continue; }
      }
      if(count) { out[out.length-1] += seq[i]; }
    }
    return out;
  }

  $.fn.newtable_filter_enumclient = function(config,data) {
    return {
      enums: [{
        name: "string",
        value: function(vv,v) { vv[v]=1; },
        finish: function(vv) { return Object.keys(vv); },
        match: function(ori,val) {
          var ok = 1;
          if(!val && val!=="") { return true; }
          $.each(ori,function(col,v) {
            if((col || col==="") && col==val) { ok = false; }
          });
          return ok;
        }
      },{
        name: "numeric",
        split: function(v) { return [number_clean(v)]; },
        value: function(vv,v) { minmax(vv,v); },
        match: function(ori,val) {
          if(is_number(val)) {
            val = parseFloat(val);
            if(ori.hasOwnProperty('min') && val<ori.min) { return false; }
            if(ori.hasOwnProperty('max') && val>ori.max) { return false; }
          } else {
            if(ori.hasOwnProperty('nulls')) { return ori.nulls; }
          }
          return true;
        }
      },{
        name: "numeric_hidden",
        split: function(v) { return [number_clean(html_hidden(v))]; },
        value: function(vv,v) { minmax(vv,v); }
      },{
        name: "html_split",
        split: function(v) {
          var raw = split_top_level(v);
          var out = [];
          for(var i=0;i<raw.length;i++) { out[i] = html_cleaned(raw[i]); }
          return out;
        },
        value: function(vv,v) { vv[v]=1; },
        finish: function(vv) { return Object.keys(vv); }
      },{
        name: "html_hidden_split",
        split: function(v) {
          var raw = split_top_level(v);
          var out = [];
          for(var i=0;i<raw.length;i++) { out[i] = html_hidden(raw[i]); }
          return out;
        },
        value: function(vv,v) { vv[v]=1; },
        finish: function(vv) { return Object.keys(vv); }
      },{
        name: "html",
        split: function(v) { return [html_cleaned(v)]; },
        value: function(vv,v) { vv[v]=1; },
        finish: function(vv) { return Object.keys(vv); }
      },{
        name: "hidden_position",
        split: function(v) { return [html_hidden(v)]; },
        value: function(vv,v) {
          var m = v.match(/^(.*?):(\d+)/);
          if(!m) { return; }
          if(!vv[m[1]]) { vv[m[1]] = { chr: m[1] }; }
          if(vv[m[1]].hasOwnProperty('min')) {
            vv[m[1]].min = vv[m[1]].min<m[2]?vv[m[1]].min:m[2];
            vv[m[1]].max = vv[m[1]].max>m[2]?vv[m[1]].max:m[2];
          } else {
            vv[m[1]].min = vv[m[1]].max = m[2];
          }
          if(!vv[m[1]].count) { vv[m[1]].count = 0; }
          vv[m[1]].count++;
        },
      }]
    };
  };
})(jQuery);
