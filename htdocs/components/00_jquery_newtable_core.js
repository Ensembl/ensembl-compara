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
  $.fn.new_table_clientsort = function(config,data) {

    function compare(a,b,plan) {
      var c = 0;
      $.each(plan,function(i,stage) {
        if(!c) {
          c = a[stage[0]].localeCompare(b[stage[0]]) * stage[1];
        }
      });
      return c;
    }

    return {
      generate: function() {},
      go: function($table,$el) {},
      pipe: function() {
        var col_idxs = {};
        $.each(config.columns,function(i,val) {
          col_idxs[val.key] = i;
        });
        return [
          function(orient) {
            if(!orient.sort) { return [orient,null]; }
            var plan  = [];
            $.each(orient.sort,function(i,stage) {
              if(!plan) { return; }
              var type = data[stage.key];
              if(!type) { plan = null; return; }
              plan.push([col_idxs[stage.key],stage.dir,type]);
            });
            if(!plan) { return [orient,null]; }
            delete orient.sort;
            return [orient,function(manifest,grid) {
              grid.sort(function(a,b) {
                return compare(a,b,plan);
              });
              return [manifest,grid];
            }];
          }
        ];
      }
    };
  }; 

})(jQuery);
