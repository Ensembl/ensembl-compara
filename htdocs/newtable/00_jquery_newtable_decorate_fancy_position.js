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
  $.fn.newtable_decorate_fancy_position = function(config,data) {
    function decorate_fn(column,extras,series) {
      return {
        go: function(html,row) {
          var m = html.match(/^(.*?):(\d+)-(\d+)([+-]?)$/);
          if(m) {
            var reg = m[2]+"-"+m[3];
            if(m[2]==m[3]) { reg = m[2]; }
            html = "<b>"+m[1]+"</b>:"+reg;
            if(m[4]) { html += " ("+m[4]+")"; }
          } 
          return html;
        }
      };
    }

    var decorators = {};
    $.each(config.colconf,function(key,cc) {
      if(cc.decorate && $.inArray("fancy_position",cc.decorate)!=-1) {
        decorators[key] = [decorate_fn];
      }
    });

    return {
      decorators: {
        fancy_position: decorators
      }
    };
  }; 

})(jQuery);
