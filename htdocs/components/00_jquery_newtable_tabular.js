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
      var help = $('<div/>').text(colconf.help).html();
      text =
        '<span class="ht _ht" title="'+help+'">'+text+'</span>';
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

  function extend_rows($table,rows) {
    var $thead = $('thead',$table);
    var $tbody = $('tbody',$table);
    var nrows = $('tr',$tbody).length;
    var ncols = $('th',$thead).length;
    for(var i=nrows;i<rows[1];i++) {
      var $row = $('<tr/>').appendTo($tbody);
      for(var j=0;j<ncols;j++) {
        $('<td/>').appendTo($row);
      }
    }
  }

  function update_row($table,data,row,columns) {
    var $row = $('tbody tr',$table).eq(row);
    var $cells = $('td',$row);
    var di = 0;
    for(var i=0;i<columns.length;i++) {
      if(!columns[i])
        continue;
      $cells.eq(i).html(data[di++]);
    }
  }

  $.fn.new_table_tabular = function(config,data) {
    return {
      layout: function($table) {
        var config = $table.data('config');
        var header = new_header(config);
        return '<table class="ss new_table">'+header+'<tbody></tbody></table>';
      },
      go: function($table,$el) {
        $('th',$table).click(function(e) {
          add_sort($table,$(this).data('key'),!e.shiftKey); 
        });
      },
      add_data: function($table,data,rows,columns) {
        console.log("add_data");
        extend_rows($table,rows);
        for(var i=rows[0];i<rows[1];i++) {
          update_row($table,data[i-rows[0]],i,columns);
        }
      }
    };
  }; 

})(jQuery);
