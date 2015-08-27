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
  $.fn.newtable_sort_numeric = function(a,b,c) {
    return (parseFloat(a)-parseFloat(b))*c;
  }

  $.fn.newtable_sort_string = function(a,b,c) {
    return a.toLowerCase().localeCompare(b.toLowerCase())*c;
  }

  $.fn.newtable_sort_position = function(a,b,f) {
    var aa = a.split(/[:-]/);
    var bb = b.split(/[:-]/);
    for(var i=0;i<aa.length;i++) {
      var c = $.fn.newtable_sort_numeric(aa[i],bb[i],f);
      if(c) { return c; }
    }
    return 0;
  }

  // TODO clean prior to sort for speed
  $.fn.newtable_clean_none = function(v) { return v; }
  $.fn.newtable_clean_html_hidden = function(v) {
    var m = v.match(/<span class="hidden">(.*?)<\/span>/);
    if(m) { return m[1]; }
    return v;
  } 
  $.fn.newtable_clean_html_cleaned = function(v) {
    return v.replace(/<.*?>/g,'');
  } 
  $.fn.newtable_clean_number = function(v) {
    return v.replace(/([\d\.e\+-])\s.*$/,'$1');
  }
  $.fn.newtable_clean_html_number = function(v) {
    return v.replace(/<.*?>/g,'').replace(/([\d\.e\+-])\s.*$/,'$1');
  }
  $.fn.newtable_clean_hidden_number = function(v) {
    v = $.fn.newtable_clean_html_hidden(v);
    return v.replace(/([\d\.e\+-])\s.*$/,'$1');
  }

  $.fn.new_table_clientsort = function(config,data) {
    var col_idxs = {};
    $.each(config.columns,function(i,val) { col_idxs[val.key] = i; });

    function compare(a,b,plan) {
      var c = 0;
      $.each(plan,function(i,stage) {
        if(!c) {
          var av = a[stage.idx];
          var bv = b[stage.idx];
          if(!av || !bv) { return 0; }
          c = av[1]-bv[1];
          if(!c) {
            c = stage.fn(stage.clean(av[0]),stage.clean(bv[0]),stage.dir);
          }
        }
      });
      return c;
    }

    function build_plan(orient) {
      var plan  = [];
      var incr_ok = true;
      $.each(orient.sort,function(i,stage) {
        if(!plan) { return; }
        if(!config.colconf[stage.key]) { plan = null; return; }
        var type = $.fn['newtable_sort_'+config.colconf[stage.key].fn];
        if(!type) { plan = null; return; }
        var clean = $.fn['newtable_clean_'+config.colconf[stage.key].clean];
        if(!clean) { clean = $.fn.newtable_clean_none; }
        plan.push({ idx: col_idxs[stage.key], dir: stage.dir, fn: type, clean: clean});
        if(!config.colconf[stage.key].incr_ok) { incr_ok = false; }
      });
      if(!plan) { return null; }
      plan.push({ idx: config.columns.length, dir: 1, fn: $.fn.newtable_sort_numeric, clean: $.fn.newtable_clean_none});
      return { stages: plan, incr_ok: incr_ok};
    }

    function mere_reversal(orient,target) {
      if(!orient.sort || !target.sort) { return null; }
      if(orient.sort.length>1 || target.sort.length>1) { return null; }
      if(orient.sort[0].key != target.sort[0].key) { return null; }
      if(orient.sort[0].dir != -target.sort[0].dir) { return null; }
      var idx = col_idxs[target.sort[0].key];
      orient.sort[0].dir *= -1;
      return function(manifest,grid) {
        var fabric = grid.slice();
        var partitioned = [[],[]];
        $.each(grid,function(i,row) {
          partitioned[row[idx][1]].push(row);
        });
        partitioned[0].reverse();
        partitioned[1].reverse();
        manifest.sort[0].dir *= -1;
        return [manifest,partitioned[0].concat(partitioned[1])];
      }
    }

    return {
      generate: function() {},
      go: function($table,$el) {},
      pipe: function() {
        return [
          function(need,got,wire) {
            if(!need.sort) { return null; }
            var rev = mere_reversal(need,got);
            if(rev) { return { undo: rev }; }
            var plan = build_plan(need);
            if(!plan) { return null; }
            wire.sort = need.sort;
            need.sort = got.sort;
            return {
              undo: function(manifest,grid) {
                var fabric = grid.slice();
                $.each(fabric,function(i,val) { val.push(i); }); // ties
                fabric.sort(function(a,b) {
                  return compare(a,b,plan.stages);
                });
                manifest.sort = wire.sort;
                return [manifest,fabric];
              },
              no_incr: !plan.incr_ok
            }
          }
        ];
      }
    };
  }; 

})(jQuery);
