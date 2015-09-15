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
  $.fn.newtable_decorate_iconic = function(config,data) {
    function decorate_fn(column,extras) {
      return function(html) {
        var values = html.split(';');
        new_html = "";
        for(var i=0;i<values.length;i++) {
          var ann = {};
          if(extras[values[i]]) { ann = extras[values[i]]; }
          if(ann.icon) {
            more = '';
            if(ann.helptip) {
              more += ' class="_ht" title="'+ann.helptip+'" ';
            }
            new_html += '<img src="'+ann.icon+'" '+more+'/>';
          } else {
            if(ann.coltab) {
              new_html += '<div class="coltab">'+
                '<span class="coltab-tab" style="background-color: '+
                ann.coltab+';">&nbsp;</span><div class="coltab-text">';
            }
            if(ann.helptip) {
              new_html += '<span class="ht _ht">'+
                '<span class="_ht_tip hidden">'+ann.helptip+'</span>';
            }
            new_html += values[i];
            if(!values[i]) { new_html += '-'; }
            if(ann.helptip) {
              new_html += '</span>';
            }
            if(ann.coltab) {
              new_html += '</div></div>';
            }
          }
          new_html += '<div class="hidden export">'+values[i]+'</div>';
        }
        return new_html;
      };
    }

    var decorators = {};
    $.each(config.colconf,function(key,cc) {
      if(cc.decorate && cc.decorate == "iconic") {
        decorators[key] = [decorate_fn];
      }
    });

    return {
      decorators: {
        iconic: decorators
      }
    };
  }; 

})(jQuery);
