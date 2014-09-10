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

  function new_th(index,colconf,$header) {
    var text = colconf.label || colconf.title || colconf.key;
    var attrs = {};
    var classes = [];
    attrs['data-key'] = colconf.key || '';
    if(colconf.width) { attrs.width = colconf.width; }
    if(colconf.sort)  { classes.push('sorting'); }
    if(colconf.help) {
      text =
        '<span class="ht _ht" title="'+colconf.help+'">'+text+'</span>';
    }
    var attr_str = "";
    $.each(attrs,function(k,v) {
      attr_str += ' '+k+'="'+v+'"';
    });
    if(classes.length) {
      attr_str += ' class="'+classes.join(' ')+'"';
    };
    return "<th "+attr_str+">"+text+"</th>";
  }

  function new_header(config) {
    var columns = [];

    var $header = $('<thead></thead>');
    $.each(config.columns,function(i,data) {
      columns.push(new_th(i,data,$header));
    });
    return '<thead><tr class="ss_header">'+columns.join('')+"</tr></thead>";
  }
  
  function add_sort($table,key,clear) {
    // Update data
    var view = $table.data('view');
    var sort = [];
    if(view && view.sort) { sort = view.sort; }
    var new_sort = [];
    var dir = 0;
    $.each(sort,function(i,val) {
      if(val.key == key) {
        dir = -val.dir;
      } else if(!clear) {
        new_sort.push(val);
      }
    });
    if(!dir) { dir = 1; }
    new_sort.push({ key: key, dir: dir });
    view.sort = new_sort;
    $table.data('view',view);
    $table.trigger('view-updated');
    // Reflect data in display
    $('th',$table).removeClass('sorting_asc').removeClass('sorting_desc');
    $.each(new_sort,function(i,val) {
      var dir = val.dir>0?'asc':'desc';
      $('th[data-key="'+val.key+'"]').addClass('sorting_'+dir);
    }); 
  }

  $.fn.new_table_paragraph = function(config,data) {
    return {
      layout: function($table) {
        var config = $table.data('config');
        var header = new_header(config);
        return '<table class="ss new_table paragraph">'+header+'</table>';
      },
      go: function($table,$el) {
        $('th',$table).click(function(e) {
          add_sort($table,$(this).data('key'),!e.shiftKey); 
        });
      }
    };
  }; 

})(jQuery);
