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
  function tabify(colour,html) {
    return '<div class="coltab">'+
      '<span class="coltab-tab" style="background-color: '+
      colour+';">&nbsp;</span><div class="coltab-text">'+
      html + '</div></div>';
  }

  $.fn.newtable_decorate_iconic = function(config,data) {
    function paint_fn(column,extras) {
      return function(value) {
        var ann = extras[value] || {};
        if(ann.icon) {
          value = '<img src="'+ann.icon+'"/>' + value;
        } else {
          if(ann.coltab) { value = tabify(ann.coltab,value); }
        }
        return value;
      };
    }

    function decorate_fn(column,extras) {
      return function(html) {
        var values = html.split('~');
        var new_html = "";
        for(var i=0;i<values.length;i++) {
          var val = "";
          var ann = {};
          if(extras[values[i]]) { ann = extras[values[i]]; }
          if(ann.icon) {
            var more = '';
            if(ann.helptip) {
              more += ' class="_tht" title="'+ann.helptip+'" ';
            }
            val = '<img src="'+ann.icon+'" '+more+'/>';
          } else {
            if(ann.helptip) {
              val = '<span class="ht _tht">'+
                '<span class="_ht_tip hidden">'+ann.helptip+'</span>';
            }
            val += values[i];
            if(!values[i]) { val += '-'; }
            if(ann.helptip) {
              val += '</span>';
            }
            if(ann.coltab) { val = tabify(ann.coltab,val); }
          }
          new_html += val;
        }
        if(!values.length || html=='') {
          new_html = '-';
        }
        return new_html;
      };
    }

    var decorators = {};
    var paints = {};
    $.each(config.colconf,function(key,cc) {
      if(cc.decorate && cc.decorate == "iconic") {
        decorators[key] = [decorate_fn];
        paints[key] = [paint_fn];
      }
    });

    return {
      decorators: {
        iconic: decorators
      },
      decorate_one: {
        iconic: paints
      }
    };
  }; 

})(jQuery);
