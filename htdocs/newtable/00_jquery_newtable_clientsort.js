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
  function cmp_numeric(a,b,f) {
    return (parseFloat(a)-parseFloat(b))*f;
  }

  // TODO clean prior to sort for speed
  $.fn.new_table_clientsort = function(config,data,widgets) {
    var col_idxs = {};
    $.each(config.columns,function(i,val) { col_idxs[val] = i; });

    function compare(a,b,rev_series,plan,cache,keymeta) {
      var c = 0;
      for(var i=0;i<plan.length;i++) {
        var stage = plan[i];
        if(!c) {
          if(!cache[stage.key]) { cache[stage.key] = {}; }
          var av = a[rev_series[stage.key]];
          var bv = b[rev_series[stage.key]];
          c = (!!(av===null || av===undefined))-(!!(bv===null || bv===undefined));
          if(!c) {
            c = stage.fn(stage.clean(av),stage.clean(bv),stage.dir,
                         cache[stage.key],keymeta,stage.key);
          }
        }
      }
      return c;
    }

    function clean_none(v) { return v; }

    function build_plan(orient) {
      var plan  = [];
      var incr_ok = true;
      $.each(orient.sort,function(i,stage) {
        if(!plan) { return; }
        if(!config.colconf[stage.key]) { plan = null; return; }
        var type = $.find_type(widgets,config.colconf[stage.key]);
        if(!type.sort) { plan = null; return; }
        var clean = type.clean;
        if(!clean) { clean = clean_none; }
        plan.push({ dir: stage.dir, fn: type.sort, clean: clean, key: stage.key });
        if(!config.colconf[stage.key].incr_ok) { incr_ok = false; }
      });
      if(!plan) { return null; }
      plan.push({ dir: 1, fn: cmp_numeric, clean: clean_none, key: '__tie' });
      return { stages: plan, incr_ok: incr_ok};
    }

    function mere_reversal(orient,target) {
      if(!orient || !target || !orient.sort || !target.sort) { return null; }
      if(orient.sort.length>1 || target.sort.length>1) { return null; }
      if(orient.sort[0].key != target.sort[0].key) { return null; }
      if(orient.sort[0].dir != -target.sort[0].dir) { return null; }
      orient.sort[0].dir *= -1;
      return function(manifest,grid,series) {
        var idx = -1;
        for(var i=0;i<series.length;i++) {
          if(series[i]==target.sort[0].key) { idx = i; }
        }
        var partitioned = [[],[]];
        $.each(grid,function(i,row) {
          partitioned[0+!!(row[idx]===null)].push(row);
        });
        partitioned[0].reverse();
        partitioned[1].reverse();
        manifest.sort[0].dir *= -1;
        return [manifest,partitioned[0].concat(partitioned[1])];
      };
    }

    return {
      generate: function() {},
      go: function($table,$el) {},
      pipe: function($table) {
        return [
          function(need,got,wire) {
            if(!need.sort) { return null; }
            var rev = mere_reversal(need,got);
            if(rev) { return { undo: rev }; }
            var plan = build_plan(need);
            if(!plan) { return null; }
            var msort = need.sort;
            need.sort = (got||{}).sort;
            $table.trigger('think-on',['sort']);
            return {
              undo: function(manifest,grid,series) {
                var rev_series = {};
                for(var i=0;i<series.length;i++) {
                  rev_series[series[i]] = i;
                }
                var fabric = grid.slice();
                $.each(fabric,function(i,val) { val[series.length] = i; });
                var cache = {};
                var keymeta = $table.data('keymeta') || {};
                series = series.slice();
                series.push('__tie');
                rev_series.__tie = series.length-1;
                fabric.sort(function(a,b) {
                  return compare(a,b,rev_series,plan.stages,cache,keymeta);
                });
                manifest.sort = msort;
                $table.trigger('think-off',['sort']);
                return [manifest,fabric];
              },
              no_incr: !plan.incr_ok
            };
          }
        ];
      }
    };
  }; 

})(jQuery);
