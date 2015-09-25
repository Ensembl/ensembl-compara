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
  function split_up(re,all) {
    var parts = [];
    while(true) {
      var m = re.exec(all);
      if(m===null) {
        parts.push(all);
        break;
      } else {
        parts.push(all.substring(0,m.index));
        all = all.substring(m.index);
        parts.push(all.substring(0,m[0].length));
        all = all.substring(m[0].length);
      }
    }
    return parts;
  }

  function add_toggler(htshort,htlong) {
    var html = '<div class="newtable_toggle">' +
      '<span class="newtable_toggle_short">'+htshort+'</span>'+
      '<span class="newtable_toggle_long">'+htlong+'</span>'+
      '<span class="newtable_toggle_img"/></div>';
    return html;
  }

  $.fn.newtable_decorate_toggle = function(config,data) {
    function decorate_fn(column,extras,series) {
      var rseries = {};
      $.each(series,function(i,v) { rseries[v] = i; });

      return function(html,row) {
        var sep = RegExp(extras['*'].separator || '\s');
        var max = (extras['*'].max || 20);
        var parts = split_up(sep,html);
        var all = parts.slice();
        var out = "";
        var trimmed = false;
        var highlight_col = extras['*'].highlight_col;
        var highlight_over = (extras['*'].highlight_over || 0);
        var highlight_value;
        if(highlight_col && parts.length>2*highlight_over) {
          highlight_value = row[rseries[highlight_col]];
        }
        for(var i=0;i<parts.length;i+=2) {
          var highlight = (parts[i] == highlight_value);
          if(parts[i].length>max) {
            parts[i] = parts[i].substring(0,max-2)+"...";
            trimmed = true;
          }
          if(highlight) {
            parts[i] = '<b>'+parts[i]+'</b>';
            all[i] = '<b>'+all[i]+'</b>';
          }
          out = out + parts[i];
          if(i<parts.length-1) {
            out = out + parts[i+1];
          }
        }
        if(trimmed) {
          return add_toggler(out,all.join(''));
        } else {
          return all.join('');
        }
      };
    }

    var decorators = {};
    $.each(config.colconf,function(key,cc) {
      if(cc.decorate && cc.decorate == "toggle") {
        decorators[key] = [decorate_fn];
      }
    });

    return {
      decorators: {
        toggle: decorators
      },
      go_data: function($some) {
        $some.find('.newtable_toggle_img').on('click',function() {
          $(this).closest('.newtable_toggle').toggleClass('open');
        });
      }
    };
  }; 

})(jQuery);
