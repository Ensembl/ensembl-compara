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

// Custom sorting functions for dataTable

$.extend($.fn.dataTableExt.oSort, {
  'numeric-asc': function (a, b) {
    a = parseFloat(a);
    b = parseFloat(b);
    var x = isNaN(a) || a === ' ' || a === '' ? 1e100 : a;
    var y = isNaN(b) || b === ' ' || b === '' ? 1e100 : b;
    return x - y;
  },
  'numeric-desc': function (a, b) {
    a = parseFloat(a);
    b = parseFloat(b);
    var x = isNaN(a) || a === ' ' || a === '' ? -1e100 : a;
    var y = isNaN(b) || b === ' ' || b === '' ? -1e100 : b;
    return y - x;
  },
  'position': function (dir, a, b) {
    var chr = !!(a.match(/:/) || b.match(/:/));
    
    a = a.split(/[:\-(]/).reverse();
    b = b.split(/[:\-(]/).reverse();
    
    if (a.length !== b.length) {
      var t = a.length < b.length ? a : b;
      t.unshift(t[0]);
    }
    
    var rtn = 0;
    
    if (chr) {
      var chrA = a.pop();
      var chrB = b.pop();
      
      if (isNaN(chrA) && isNaN(chrB)) {
        rtn = this['string-' + dir](chrA, chrB);
      } else if (isNaN(chrA)) {
        rtn = dir === 'asc' ? 1 : -1;
      } else if (isNaN(chrB)) {
        rtn = dir === 'asc' ? -1 : 1;
      } else {
        rtn = this['numeric-' + dir](parseInt(chrA, 10), parseInt(chrB, 10));
      }
      
      if (rtn) {
        return rtn;
      }
    }
    
    var i = a.length;
    
    while (i--) {
      rtn = this['numeric-' + dir](parseInt(a[i], 10), parseInt(b[i], 10));
      
      if (rtn) {
        break;
      }
    }
    
    return rtn;
  },
  'position-asc': function (a, b) {
    return this.position('asc', a, b);
  },
  'position-desc': function (a, b) {
    return this.position('desc', a, b);
  },
  'position_html-asc': function (a, b) {
    return this.position('asc', a.replace(/<.*?>/g, ''), b.replace(/<.*?>/g, ''));
  },
  'position_html-desc': function (a, b) {
    return this.position('desc', a.replace(/<.*?>/g, ''), b.replace(/<.*?>/g, ''));
  },
  'string-asc': function (a, b) {
    var x = a === ' ' || a === '-' || a.toLowerCase() === 'n/a' ? 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz' : a.toLowerCase();
    var y = b === ' ' || b === '-' || b.toLowerCase() === 'n/a' ? 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz' : b.toLowerCase();
    return ((x < y) ? -1 : ((x > y) ? 1 : 0));
  },
  'string-desc': function (a, b) {
    var x = a === ' ' || a === '-' || a.toLowerCase() === 'n/a' ? '' : a.toLowerCase();
    var y = b === ' ' || b === '-' || b.toLowerCase() === 'n/a' ? '' : b.toLowerCase();
    return ((x < y) ? 1 : ((x > y) ? -1 : 0));
  },
  'string_hidden-asc': function (a, b) {
    return this['string-asc']((a.match(/<.*?>(.+)<\/.*?>/) || ['', a])[1], (b.match(/<.*?>(.+)<\/.*?>/) || ['', b])[1]);
  },
  'string_hidden-desc': function (a, b) {
    return this['string-desc']((a.match(/<.*?>(.+)<\/.*?>/) || ['', a])[1], (b.match(/<.*?>(.+)<\/.*?>/) || ['', b])[1]);
  },
  'numeric_hidden-asc': function (a, b) {
    return this['numeric-asc']((a.match(/<.*?>(.+)<\/.*?>/) || a.match(/^(\d+)$/) || [])[1], (b.match(/<.*?>(.+)<\/.*?>/) || b.match(/^(\d+)$/) || [])[1]);
  },
  'numeric_hidden-desc': function (a, b) {
    return this['numeric-desc']((a.match(/<.*?>(.+)<\/.*?>/) || a.match(/^(\d+)$/) || [])[1], (b.match(/<.*?>(.+)<\/.*?>/) || b.match(/^(\d+)$/) || [])[1]);
  },
  'html-asc': function (a, b) {
    return this['string-asc'](a.replace(/<.*?>/g, ''), b.replace(/<.*?>/g, ''));
  },
  'html-desc': function (a, b) {
    return this['string-desc'](a.replace(/<.*?>/g, ''), b.replace(/<.*?>/g, ''));
  },
  'html_numeric-asc': function (a, b) {
    function the_number(x) {
      return x.replace(/<.*?>/g,'').replace(/[^0-9]/g,'');
    };
    return this['numeric-asc'](the_number(a),the_number(b));
  },
  'html_numeric-desc': function (a, b) {
    function the_number(x) {
      return x.replace(/<.*?>/g,'').replace(/[^0-9]/g,'');
    };
    return this['numeric-desc'](the_number(a),the_number(b));
  }
});
