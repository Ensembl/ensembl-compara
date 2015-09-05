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
  $.fn.newtable_decorate = function(config,data,widgets) {
    function do_decorate(ff_in,extras) {
      var ff_out = [];
      for(var i=0;i<ff_in.length;i++) {
        var f = ff_in[i](extras);
        if(f) { ff_out.push(f); }
      }
      return ff_out;
    }

    function find_decorators(decorators,type,column,extras) {
      $.each(widgets,function(name,w) {
        if(w.decorators && w.decorators[type] && 
           w.decorators[type][column]) {
          var ff = do_decorate(w.decorators[type][column],extras);
          if(!decorators[column]) { decorators[column] = []; }
          decorators[column] = decorators[column].concat(ff);
        }
      });
    }

    function make_decorators($table) {
      var decorators = {};
      var km = $table.data('keymeta') || {};
      var extras = {};
      $.each(km,function(key,kmvalues) {
        var t = key.split('/',4);
        if(t[0] == 'decorate') {
          if(!extras[t[1]]) { extras[t[1]] = {}; }
          if(!extras[t[1]][t[2]]) { extras[t[1]][t[2]] = {}; }
          extras[t[1]][t[2]][t[3]] = kmvalues;
        }
      });
      var decorators = {};
      $.each(extras,function(type,vv) {
        $.each(vv,function(col,extras) {
          find_decorators(decorators,type,col,extras);
        });
      });
      return decorators;
    }

    return {
      prio: 90,
      pipe: function($table) {
        return [
          function(need,got) {
            return {
              undo: function(manifest,grid,dest) {
                var fabric = [];
                var decorators = make_decorators($table);
                for(var i=0;i<grid.length;i++) {
                  var new_row = [];
                  for(var j=0;j<grid[i].length;j++) {
                    var v = grid[i][j];
                    if(v!==undefined && config.columns[j]) {
                      v = v[0];
                      if(decorators[config.columns[j].key]) {
                        var ff = decorators[config.columns[j].key];
                        for(var k=0;k<ff.length;k++) {
                          v = ff[k](v);
                        }
                      }
                      v = [v,grid[i][j][1]];
                    }
                    new_row[j] = v;
                  }
                  fabric[i] = new_row;
                }
                return [manifest,fabric];
              },
            };
          }
        ];
      }
    };
  }; 

})(jQuery);
