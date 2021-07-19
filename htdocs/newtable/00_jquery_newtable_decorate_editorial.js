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
  $.fn.newtable_decorate_editorial = function(config,data) {
    function decorate_fn(column,extras,series) {
      var colkey = column;
      if(extras['*'] && extras['*'].source) {
        colkey = extras['*'].source;
      }
      var idx = -1;
      for(var i=0;i<series.length;i++) {
        if(series[i]==colkey) { idx = i; }
      }
      return {
        go: function(html,row) {
          if(idx==-1) { return html; }
          if(!html) { return '-'; }
          var type = row[idx];
          var style = extras[type];
          if(!style) { return html; }
          var helptip = (style.helptip || type);
          return '<div align="center"><div title="'+helptip+'" class="_ht score '+style.cssclass+'">'+html+'</div></div>';
        }
      };
    }

    var decorators = {};
    $.each(config.colconf,function(key,cc) {
      if(cc.decorate && $.inArray("editorial",cc.decorate)!=-1) {
        decorators[key] = [decorate_fn];
      }
    });

    return {
      decorators: {
        editorial: decorators
      }
    };
  }; 

})(jQuery);
