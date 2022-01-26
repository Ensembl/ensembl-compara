/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2022] EMBL-European Bioinformatics Institute
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
    function do_decorate(column,ff_in,extras,series,gextras) {
      var ff_out = [];
      for(var i=0;i<ff_in.length;i++) {
        var f = ff_in[i](column,extras,series,gextras);
        if(f) { ff_out.push(f); }
      }
      return ff_out;
    }

    function find_decorators(decorators,type,column,extras,fnname,series,gextras) {
      $.each(widgets,function(name,w) {
        if(w[fnname] && w[fnname][type] && w[fnname][type][column]) {
          var ff = do_decorate(column,w[fnname][type][column],extras,series,gextras);
          if(!decorators[column]) { decorators[column] = []; }
          decorators[column] = decorators[column].concat(ff);
        }
      });
      $.each(decorators,function(k,v) {
        v.sort(function(a,b) { return (b.prio||50)-(a.prio||50); });
      });
    }

    function make_decorators($table,fnname,series) {
      var decorators = {};
      var km = $table.data('keymeta') || {};
      var gextras = {};
      $.each(km,function(key,keyvalues) {
        var t = key.split('/',2);
        if(t[0] == 'decorate') {
          gextras[t[1]] = keyvalues;
        }
      });
      var decorators = {};
      $.each(gextras,function(type,vv) {
        $.each(vv,function(col,extras) {
          find_decorators(decorators,type,col,extras,fnname,series,gextras);
        });
      });
      return decorators;
    }

    return {
      prio: 90,
      paint: function($table,key,value) {
        return [
          function() {
            var decorators = make_decorators($table,'decorate_one');
            var ff = decorators[key] || [];
            for(var i=0;i<ff.length;i++) {
              value = ff[i].go(value);
            }
            if(value=='') { value = 'No data'; }
            return value;
          }]; 
      },
      pipe: function($table) {
        return [
          function(need,got) {
            return {
              dundo: function(manifest,grid,series,start,length) {
                var fabric = [];
                var decorators = make_decorators($table,'decorators',series);
                for(var i=0;i<grid.length;i++) { fabric[i] = grid[i]; }
                for(var i=start;i<start+length;i++) {
                  var new_row = [];
                  for(var j=0;j<grid[i].length;j++) {
                    var v = grid[i][j];
                    var key = series[j];
                    if(v===undefined || v===null) { v=""; }
                    if(decorators[key]) {
                      var ff = decorators[key];
                      for(var k=0;k<ff.length;k++) {
                        v = ff[k].go(v,grid[i],series);
                      }
                    }
                    if(!v) { v = '-'; }
                    new_row[j] = v;
                  }
                  fabric[i] = new_row;
                }
                return fabric;
              }
            };
          }
        ];
      }
    };
  }; 

})(jQuery);
