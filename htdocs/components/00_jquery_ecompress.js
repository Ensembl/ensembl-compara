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
  var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef"+
              "ghijklmnopqrstuvwxyz0123456789+-";
  var unchars = {};
  for(var i=0;i<chars.length;i++) { unchars[chars.substr(i,1)] = i; }

  function logfloor(x) {
    var v=0;
    while(x) { x>>=1; v++; }
    return v;
  }

  function emitter() {
    var out = "";
    var stream_bits_left = 0;
    var next_char = 0;

    var fn = {
      stream: function() { 
        if(stream_bits_left!=6) { out += chars.substr(next_char,1); }
        return out.slice(1);
      },
      emit_bits: function(input,input_bits_left) {
        while(input_bits_left) {
          input_bits_left -= stream_bits_left;
          if(input_bits_left>0) {
            out += chars.substr(next_char|(input>>input_bits_left),1);
            input &= (1<<input_bits_left)-1;
            next_char = 0;
            stream_bits_left = 6;
          } else {
            next_char |= input<<-input_bits_left;
            stream_bits_left = -input_bits_left;
            break;
          }
        }
      },
      max_emitter: function(M) {
        var b = -1;
        var g = M;
        while(g) { g>>=1; b++; }
        g = 1<<b;
        return function(r) {
          if(r>=2*g-M) {
            fn.emit_bits(r+2*g-M,b+1);
          } else {
            fn.emit_bits(r,b);
          }
        };      
      },
      golomb_emitter: function(M) {
        var mx = fn.max_emitter(M);
        return function(v) {
          var r = v%M;
          var q = (v-r)/M;
          while(q>16) { fn.emit_bits((1<<15)-1,15); q-= 15; }
          fn.emit_bits(((1<<q)-1)<<1,q+1);
          mx(r);
        };
      },
      gamma_bits: function(v) {
        var d = logfloor(v+1)-1;
        fn.emit_bits(((1<<d)-1)<<1,d+1);
        if(d) { fn.emit_bits(v+1-(1<<d),d); }
      },
      huffman_encoder: function(counts) {
        /* calculate codes */
        var code = 0;
        var b = -1;
        var n = 0;
        var symbols = [];
        for(var i=0;b<counts.length;i++) {
          if(!n) {
            do { code *= 2; b++; } while(b<counts.length && counts[b]==0);
            if(b==counts.length) { break; }
            n = counts[b];
          }
          symbols[i] = [code,b];
          code++;
          n--;
        }
        return function(v) {
          fn.emit_bits(symbols[v][0],symbols[v][1]);
        };
      },
      b_encoder: function(b) {
        var b_init = b;
        var c = 0;
        return function(v) {
          var r = v%(1<<b);
          var q = (v-r)/(1<<b);
          if(q<3) {
            fn.emit_bits(((1<<q)-1)<<1,q+1);
          } else {
            fn.emit_bits(7,3);
            fn.gamma_bits(q-3);
          }
          fn.emit_bits(r,b);
          if(q>0) { c+=2; } else { c--; }
          if(c>=2) {
            b++; c=0;
          } else if(c<=-2) { 
            if(b>b_init) { b--; } c=0;
          }
        };
      },
    }
    return fn;
  }

  function receiver(raw) {
    var p = -1;
    var f = 0;
    var v = 0;
    var b = 4;
    
    function bit() {
      f>>=1;
      if(!f) { p++; v = unchars[raw.substr(p,1)]; f = 32; }
      return v&f;
    }

    var fn = {
      fixed: function(n) {
        var r = 0;
        for(var i=0;i<n;i++) { r = (r<<1)|!!bit(); }
        return r;
      },
      max_receiver: function(M) {
        var b = -1;
        var g = M;
        while(g) { g>>=1; b++; }
        g = 1<<b;
        return function() {
          var r = 0;
          for(var j=0;j<b;j++) {
            r = (r<<1)|!!bit();
          }
          if(r>=2*g-M) {
            r = ((r<<1)|!!bit())-(2*g-M);
          }
          return r;
        };
      },
      golomb_receiver: function(M) {
        var mx = fn.max_receiver(M);
        return function() {
          var q = 0;
          while(bit()) { q++; }
          var r = mx();
          return q*M+r;
        };
      },
      gamma_bits: function() {
        var q = 0;
        var r = 0;
        while(bit()) { q++; }
        for(var i=0;i<q;i++) { r = (r<<1)|!!bit(); }
        return (1<<q)+r-1;
      },
      huffman_decoder: function(counts) {
        var boff = [];
        var bst = [];
        var code = 0;
        var bnum = 0;
        for(var i=0;i<counts.length;i++) {
          bst[i] = bnum;
          boff[i] = code;
          code = (code+counts[i])*2;
          bnum += counts[i];
        }
        return function() {
          var x = 0;
          var b = 0;
          while(true) {
            if(x < counts[b]+boff[b]) {
              return x-boff[b]+bst[b];
            }
            b++;
            x = (x<<1)|!!bit();
          }
        };
      },
      b_decoder: function(b) {
        var c = 0;
        var b_init = b;
        return function() {
          var q = 0;
          while(q<3 && bit()) { q++; }
          if(q==3) { q = fn.gamma_bits()+3; }
          var r = 0;
          for(var j=0;j<b;j++) { r = (r<<1)|!!bit(); }
          var out = q*(1<<b)+r;
          if(q>0) { c+=2; } else { c--; }
          if(c>=2) {
            b++; c=0;
          } else if(c<=-2) { 
            if(b>b_init) { b--; } c=0;
          }
          return out;
        };
      },
    };
    return fn;
  }

  function data_freqs(data) {
    var rfreqs = {};
    for(var i=0;i<data.length;i++) {
      if(!rfreqs[data[i]]) { rfreqs[data[i]] = 0; }
      rfreqs[data[i]]++;
    }
    return rfreqs;
  }

  function compile_hapax(data,rfreqs) {
    var hapax = [];
    for(var i=0;i<data.length;i++) {
      if(rfreqs[data[i]]==1) {
        hapax.push(data[i]);
      }
    }
    return hapax;
  }

  function compile_napax(data,rfreqs,hapaxen,supremes) {
    var rsup = {};
    for(var i=0;i<supremes.length;i++) { rsup[supremes[i].value]=1; }
    var codes = {};
    var library = [];
    var freqs = [];
    var next_code = 1;
    for(var i=0;i<data.length;i++) {
      if(rfreqs[data[i]]!=1 && !rsup[data[i]]) {
        if(!codes.hasOwnProperty(data[i])) {
          codes[data[i]] = next_code++;
          library.push(['r',data[i]]);
          freqs[codes[data[i]]] = rfreqs[data[i]];
        }
      }
    }
    freqs[next_code++] = hapaxen;
    library.push(['h']);
    return { freqs: freqs, codes: codes, library: library };
  }

  function extract_supremes(rfreqs,length) {
    var hit = {};
    var supremes = [];
    while(length>0) {
      var supreme = null;
      for(var k in rfreqs) {
        if(!rfreqs.hasOwnProperty(k) || hit[k]) { continue; }
        if(supreme===null || rfreqs[k]>rfreqs[supreme]) {
          supreme = k;
        }
      }
      if(supreme==null || rfreqs[supreme]<length/2 || rfreqs[supreme]<2) {
        break;
      }
      var p = rfreqs[supreme]/length;
      var M = 24;
      if(p<1) {
        M = Math.round(-Math.log(2)/Math.log(p));
      }
      if(M < 2) { break; }
      supremes.push({value: supreme, M: M });
      hit[supreme] = 1;
      length -= rfreqs[supreme];
    }
    return supremes;
  }

  // TODO empty list
  function build_library(data) {
    var rfreqs = data_freqs(data);
    var supremes = extract_supremes(rfreqs,data.length);
    var hapax = compile_hapax(data,rfreqs);
    var lib = compile_napax(data,rfreqs,hapax.length,supremes);
    return { lib: lib.library, hapax: hapax, freqs: lib.freqs, supremes: supremes };
  }

  function calc_lengths(freqs) {
    var parents = [];

    var count = freqs.length-1;
    for(var i=0;i<count-1;i++) {
      var a = -1;
      var b = -1;
      for(var j=1;j<freqs.length;j++) {
        if(!parents[j]) {
          if(a==-1 || freqs[j]<freqs[a]) { b = a; a = j; }
          else if(b==-1 || freqs[j]<freqs[b]) { b = j; }
        }
      }
      var p = freqs.length;
      parents[a] = p;
      parents[b] = p;
      freqs[p] = freqs[a]+freqs[b];
    }
    var lengths = [];
    lengths[freqs.length-1] = 0;
    for(var i = freqs.length-2;i>0;i--) {
      lengths[i] = lengths[parents[i]]+1;
    }
    return lengths.slice(0,count+1);
  }

  function make_canonical(lengths) {
    var sorder = [];
    for(var i=0;i<lengths.length-1;i++) { sorder[i] = i; }
    sorder.sort(function(a,b) { return lengths[a+1]-lengths[b+1]; });
    var cnum = [];
    for(var i=0;i<lengths.length-1;i++) {
      if(!cnum[lengths[i+1]]) { cnum[lengths[i+1]] = 0; }
      cnum[lengths[i+1]]++;
    }
    for(var i=0;i<cnum.length;i++) { if(!cnum[i]) { cnum[i]=0; }}
    return { counts: cnum, order: sorder};
  }

  function sort_library(library,cnums) {
    var slibrary = [];
    for(var i=0;i<library.length;i++) { slibrary[i] = library[cnums[i]]; }
    return slibrary;
  }

  function build_map(slibrary,hapax) {
    var map = {};
    var hcode = -1;

    for(var i=0;i<slibrary.length;i++) {
      if(slibrary[i][0]=='r') { map[slibrary[i][1]]=['r',i]; }
      if(slibrary[i][0]=='h') { hcode = i; }
    }
    for(var i=0;i<hapax.length;i++) {
      map[hapax[i]]=['r',hcode];
    }
    map['EOF'] = ['r',hcode];
    return map;
  }

  function data_to_codes2(em,data,map,supremes,counts) {
    var out = [];
    var w = [];
    var v = supremes.length;
    for(var i=0;i<=data.length;i++) {
      for(var j=0;j<v;j++) {
        w[j] = out.length;
        out.push([j,0]);
      }
      if(i==data.length) {
        out.push([-1,'EOF']);
        break;
      }
      v = -1;
      for(var j=0;j<supremes.length;j++) {
        if(data[i] == supremes[j].value) { v=j; break; }
      }
      if(v==-1) {
        out.push([-1,data[i]]);
        v = supremes.length;
      } else {
        out[w[v]][1]++;
      }
    }
    var huff = em.huffman_encoder(counts);
    var gol = [];
    for(var j=0;j<supremes.length;j++) {
      gol[j] = em.golomb_emitter(supremes[j].M);
    }
    for(var i=0;i<out.length;i++) {
      if(out[i][0]==-1) {
        huff(map[out[i][1]][1]);
      } else {
        gol[out[i][0]](out[i][1]);
      }
    }
    return out;
  }

  function codes_to_data2(rc,library,hapax,supremes,counts) {
    hapax = hapax.reverse();
    var out = [];
    var w = [];
    var huff = rc.huffman_decoder(counts);
    var gol = [];
    for(var j=0;j<supremes.length;j++) {
      gol[j] = rc.golomb_receiver(supremes[j].M);
    }
    for(var j=0;j<supremes.length;j++) {
      w[j] = gol[j]();
    }
    for(var i=0;;i++) {
      var v = -1;
      for(j=0;j<supremes.length;j++) {
        if(w[j]--) { v = j; break; }
      }
      if(v==-1) {
        var v = library[huff()];
        if(v[0] == 'r') { out.push(v[1]); }
        else if(hapax.length) { out.push(hapax.pop()); }
        else { break; }
        v = supremes.length;
      } else {
        out.push(supremes[v].value);
      }
      for(var j=0;j<v;j++) {
        w[j] = gol[j]();
      }
    }
    return out;
  }

  function emit_library(em,b,slib,hapax) {
    var out = [];
    for(var i=0;i<slib.length;i++) {
      if(slib[i][0] == 'r') {
        var v = slib[i][1];
        b(v>=0?v*2+1:2-v*2);
      } else if(slib[i][0] == 'h') {
        b(0);
      }
    }
    b(0);
    for(var i=0;i<hapax.length;i++) {
      v = hapax[i];
      b(v>=0?v*2+1:2-v*2);
    }
    b(0);
  }

  function receive_counts(rc) {
    var n = 1;
    var out = [];
    for(var i=0;n;i++) {
      var x = rc.max_receiver(n+1);
      var v = x();
      out.push(v);
      n = (n-v)*2;
    }
    return out;
  }

  function emit_counts(em,counts) {
    var n = 1;
    for(var i=0;n;i++) {
      var x = em.max_emitter(n+1);
      x(counts[i]);
      n = (n-counts[i])*2;
    }
  }

  function receive_library(rc,b) {
    var out = [];
    var n = 0;
    var h = -1;
    for(var i=0;;i++) {
      var v = b();
      if(v%2) {
        out.push(['r',(v-1)/2]);
      } else if(v) {
        out.push(['r',(2-v)/2]);
      } else {
        n++;
        if(n==3) { break; }
        else if(n==2) { h=i; }
        else { out.push(["h"]); }
      }
    }
    var hapax = [];
    for(var i=h;i<out.length;i++) { hapax.push(out[i][1]); }
    out = out.slice(0,h);
    return { lib: out, hapax: hapax };
  }

  function receive2(rc) {
    var nsup = rc.gamma_bits();
    var supremes = [];
    var b = rc.b_decoder(2);
    for(var i=0;i<nsup;i++) {
      var M = rc.gamma_bits();
      var v = b();
      if(v%2) { v = (v-1)/2 } else { v = 1-v/2; }
      supremes[i] = { value: v, M: M };
    }
    var lib = receive_library(rc,b);
    var counts = receive_counts(rc);
    return codes_to_data2(rc,lib.lib,lib.hapax,supremes,counts);
  }

  function emit_supremes(em,b,supremes) {
    em.gamma_bits(supremes.length);
    for(var i=0;i<supremes.length;i++) {
      em.gamma_bits(supremes[i].M);
      b(supremes[i].value>=0?supremes[i].value*2+1:2-supremes[i].value*2);    
    }
  }

  function encode(em,data) {
    var lib = build_library(data);
    var canon = make_canonical(calc_lengths(lib.freqs));
    var sorted = sort_library(lib.lib,canon.order);
    var map = build_map(sorted,lib.hapax);
    var b = em.b_encoder(2);
    emit_supremes(em,b,lib.supremes);
    emit_library(em,b,sorted,lib.hapax);
    emit_counts(em,canon.counts);
    data_to_codes2(em,data,map,lib.supremes,canon.counts);
  }

  $.ecompress = function(data) {
    var em = emitter();
    encode(em,data);
    return em.stream();
  };

  $.euncompress = function(raw) {
    var rc = receiver(raw);
    return receive2(rc);
  };
})(jQuery);
