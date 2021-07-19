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
  function is_number(x) {
    try { return !isNaN(parseFloat(x)); } catch(error) { return false; }
  }

  function number_clean(x) {
    if(!x) { return x; }
    return (x+"").replace(/([\d\.e\+-])\s.*$/,'$1');
  }

  function minmax(vv,v) {
    if(!is_number(v)) { return; }
    if(vv.hasOwnProperty('min')) {
      v = parseFloat(v);
      vv.min = vv.min<v?vv.min:v;
      vv.max = vv.max>v?vv.max:v;
    } else {
      vv.min = vv.max = v;
    }
  }

  function string_match(ori,val,empty) {
    var ok = true;
    if(!val && val!=="") { return true; }
    if(Object.keys(ori).length && !val) { return false; }
    $.each(ori,function(col,v) {
      if((col || col==="") && col==val) { ok = false; }
    });
    return ok;
  }

  function number_match(ori,val) {
    if(is_number(val)) {
      val = parseFloat(val);
      if(ori.hasOwnProperty('min') && val<ori.min) { return false; }
      if(ori.hasOwnProperty('max') && val>ori.max) { return false; }
    } else {
      if(ori.hasOwnProperty('no_nulls')) { return !ori.no_nulls; }
    }
    return true;
  }

  function position_match(ori,val) {
    var pat = ori.chr+":";
    if(val.indexOf(pat)===0) {
      val = parseFloat(val.substr(pat.length));
      if(ori.hasOwnProperty('min') && val<ori.min) { return false; }
      if(ori.hasOwnProperty('max') && val>ori.max) { return false; }
    } else {
      if(ori.hasOwnProperty('nulls')) { return ori.nulls; }
    }
    return true;
  }
  
  function position_sort(a,b,f) {
    var aa = a.split(/[:-]/);
    var bb = b.split(/[:-]/);
    for(var i=0;i<aa.length;i++) {
      var c = 0;
      if(!isNaN(aa[i])) {
        if(!isNaN(bb[i])) {
          c = (parseFloat(aa[i])-parseFloat(bb[i]))*f;
        } else {
          c = -f;
        }
      } else {
        if(!isNaN(bb[i])) {
          c = f;
        } else {
          c = aa[i].localeCompare(bb[i])*f;
        }
      }
      if(c) { return c; }
    }
    return 0;
  }
  
  function iconic_string(val,km,col) {
    var vals = (val||'').split(/~/);
    if(km) {
      var new_vals = [];
      for(var i=0;i<vals.length;i++) {
        var v = vals[i];
        var w = (km['decorate/iconic'][col]||{})[v];
        if(w && w.order) {
          v = ""+w.order;
          v = (Array(17-v.length).join('0'))+v;
        }
        else if(w && w['export']) { v = w['export']; }
        else { v = '~'+v; }
        new_vals.push(v);
      }
      vals = new_vals;
    }
    vals.sort();
    vals.reverse();
    return vals.join('~');
  }

  function iconic_sort(a,b,f,c,km,col) {
    if(((((km['decorate/iconic']||{})[col])||{})['*']||{}).icon_source) {
      return a.localeCompare(b)*f;
    }
    if(!c[a] && c[a]!=='') { c[a] = iconic_string(a,km,col); }
    if(!c[b] && c[b]!=='') { c[b] = iconic_string(b,km,col); }
    return c[a].localeCompare(c[b])*-f;
  }

  function iconic_finish(vv,col,km) {
    var kk = Object.keys(vv);
    kk.sort(function(a,b) {
      var aa = (((km['decorate/iconic']||{})[col]||{})[a]||{}).order;
      var bb = (((km['decorate/iconic']||{})[col]||{})[b]||{}).order;
      if(aa && bb) { return aa-bb; }
      if(aa) { return 1; }
      if(bb) { return -1; }
      if(a && b) { return a.localeCompare(b); }
      if(a) { return 1; }
      if(b) { return -1; }
      return 0;
    });
    var cc = {};
    for(var i=0;i<kk.length;i++) {
      cc[kk[i]] = vv[kk[i]];
    }
    return { keys: kk, counts: cc };
  }

  function rangemerge_class(a,b) {
    var i;
    var kk = [];
    var cc = {};
    $.each(((a||{}).keys)||{},function(i,v) {
      kk.push(v);
      cc[v] = a.counts[v];
    });
    $.each(((b||{}).keys)||{},function(i,v) {
      if(!cc.hasOwnProperty(v)) { kk.push(v); cc[v] = 0; }
      cc[v] = b.counts[v];
    });
    return { keys: kk, counts: cc };
  }

  function rangemerge_range(a,b) {
    a = $.extend({},true,a);
    if(b.hasOwnProperty('min')) {
      if(!a.hasOwnProperty('min')) { a.min = b.min; }
      a.min = a.min<b.min?a.min:b.min;
    }
    if(b.hasOwnProperty('max')) {
      if(!a.hasOwnProperty('max')) { a.max = b.max; }
      a.max = a.max>b.max?a.max:b.max;
    }
    return a;
  }

  function rangemerge_position(a,b) {
    a = $.extend({},true,a);
    $.each(b,function(name,chr) {
      if(!a[name]) { a[name] = { count: 0, chr: name }; }
      a[name].count += chr.count;
      if(chr.hasOwnProperty('min')) {
        if(!a[name].min || a[name].min>chr.min) { a[name].min = chr.min; }
      }
      if(chr.hasOwnProperty('max')) {
        if(!a[name].max || a[name].max<chr.max) { a[name].max = chr.max; }
      }
    });
    var best = null;
    $.each(a,function(name,chr) {
      if(best===null || chr.count > best.count) { best = chr; }
      chr.best = false;
    });
    if(best) {
      best.best = true;
    }
    return a;
  }

  // IE9-- polyfill
  if (!Object.keys) {
    Object.keys = function(obj) {
      var keys = [];

      for (var i in obj) {
        if (obj.hasOwnProperty(i)) {
          keys.push(i);
        }
      }

      return keys;
    };
  }

  $.fn.newtable_types = function(config,data) {
    return {
      types: [{
        name: "string",
        split: function(v) { return v?[v]:[]; },
        value: function(vv,v,s) { vv[v]=1; },
        finish: function(vv) { return Object.keys(vv); },
        match: function(ori,val) { return string_match(ori,val); },
        sort: function(a,b,c) {
          return a.toLowerCase().localeCompare(b.toLowerCase())*c;
        },
        merge: rangemerge_class
      },{
        name: "numeric",
        clean: function(v) { return number_clean(v); },
        split: function(v) { return [number_clean(v)]; },
        value: function(vv,v,s) { minmax(vv,v); },
        match: function(ori,val) { return number_match(ori,val); },
        sort: function(a,b,c) { return (parseFloat(a)-parseFloat(b))*c; },
        merge: rangemerge_range
      },{
        name: "position",
        value: function(vv,v,s) {
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
        match: function(ori,val) { return position_match(ori,val); },
        sort: position_sort,
        merge: rangemerge_position
      },{
        name: "iconic",
        split: function(v) { return v?v.split(/~/):[]; },
        value: function(vv,v,s) {
          if(s===undefined || s===null) { s=1; }
          if(v===null) { v=''; }
          if(!vv[v]) { vv[v]=0; }
          vv[v]+=s;
        },
        finish: iconic_finish,
        match: function(ori,val) {
          if(val===null && ori['']) { return false; }
          return string_match(ori,val);
        },
        sort: iconic_sort,
        merge: rangemerge_class
      }]
    };
  };
})(jQuery);
