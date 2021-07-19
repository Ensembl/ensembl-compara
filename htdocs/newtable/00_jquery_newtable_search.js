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
  $.fn.new_table_search = function(config,data,widgets,callw) {

    function identity_fn(x) { return x; }

    function match(colconf,row,series,search,cleaner) {
      for(var i=0;i<row.length;i++) {
        var key =series[i];
        var cc = colconf[key];
        if(cleaner[key]===undefined) { continue; }
        if(!row[i]) { continue; }
        if(callw('unshowable',cc)._any) { continue; }
        var val = row[i];
        if(cleaner[key]) { val = cleaner[key](val); }
        if(val===undefined) { return false; }
        if(~val.toLowerCase().indexOf(search)) { return true; }
      }
      return false;
    }

    // IE polyfill
    if(typeof String.prototype.trim !== 'function') {
      String.prototype.trim = function() {
        return this.replace(/^\s+|\s+$/g,'');
      }
    }

    function changed($table,value) {
      value = value.trim();
      var old_val = $table.data('search-value');
      if(old_val == value) { return; }
      $table.data('search-value',value);
      var view = $table.data('view');
      if(value!=="") {
        view.search = value;
      } else {
        delete view.search;
      }
      $table.data('view',view).trigger('view-updated');
    }

    return {
      generate: function() {
        var out = '<input class="search" placeholder="Search..."/>';
        return out;
      },
      go: function($table,$el) {
        var $box = $('.search',$el);
        var change_event = $.whenquiet(function($table) {
          changed($table,$box.val());
        },1000);
        $box.on("propertychange change keyup paste input",function() {
          change_event($table);
        });
        /* Default value? */
        var value = $table.data('view').search;
        if(value) { $box.val(value); }
        $table.on('view-updated',function() {
          var value = $table.data('view').search;
          if(value) { $box.val(value); }
        });
      },
      position: data.position,
      pipe: function() {
        return [
          function(need,got) {
            var orig_search = need.search;
            var search = orig_search;
            var search_was_defined = need.hasOwnProperty('search');
            delete need.search;
            if(!search_was_defined) { search = ""; }
            if(!search) { return null; }
            var cleaner = {};
            var off = need.off_columns || {};
            for(var i=0;i<config.columns.length;i++) {
              if(off[config.columns[i]]) { continue; }
              var type = $.find_type(widgets,config.colconf[config.columns[i]]);
              var fn;
              if(type) { fn = type.clean; }
              if(!fn) { fn = identity_fn; }
              if(fn) { cleaner[config.columns[i]] = fn; }
            }
            // XXX should search be searching columns or series?
            return {
              undo: function(manifest,grid,series,dest) {
                var fabric = [];
                for(var i=0;i<grid.length;i++) {
                  if(match(config.colconf,grid[i],series,search.toLowerCase(),cleaner)) {
                    fabric.push(grid[i]);
                  }
                }
                if(search_was_defined) {
                  manifest.search = orig_search;
                }
                return [manifest,fabric];
              },
              all_rows: true
            };
          }
        ];
      }
    };
  }; 

})(jQuery);
