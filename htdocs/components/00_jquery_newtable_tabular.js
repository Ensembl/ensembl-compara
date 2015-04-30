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
  var rows_per_subtable = 1000;

  function beat(def,sleeplen) {
    return def.then(function(data) {
      var d = $.Deferred();
      setTimeout(function() { d.resolve(data); },sleeplen);
      return d;
    });
  }

  function loop(def,fn,group,sleeplen) {
    return def.then(function(raw_input) {
      var input = [];
      $.each(raw_input,function(a,b) { input.push([a,b]); });
      d = $.Deferred().resolve(input);
      var output = [];
      for(var ii=0;ii<input.length;ii+=group) {
        (function(i) {
          d = beat(d.then(function(j) {
            for(j=0;j<group && i+j<input.length;j++) {
              var c = fn(input[i+j][0],input[i+j][1]);
              if(c !== undefined) {
                output.push(c);
              }
            }
            return $.Deferred().resolve(output);
          }),sleeplen);
        })(ii);
      }
      return d;
    });
  }

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
    return '<thead><tr>'+columns.join('')+"</tr></thead>";
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

  function new_subtable($table) {
    return $("<table><tbody></tbody></table>");
  }

  function extend_rows($table,rows) {
    var $thead = $('thead',$table);
    var $tbody = $('tbody',$table);
    var nrows = $('tr',$tbody).length;
    var ncols = $('th',$thead).length;
    var row = "<tr>";
    for(var i=0;i<ncols;i++) {
      row += "<td></td>";
    }
    row += "</tr>";
    var target = rows[1];
    var $subtables = $('table',$table);
    for(var i=0;i<$subtables.length;i++) {
      var $subtable;
      if(i+1 >= $subtables.length) {
        $subtable = new_subtable($table).appendTo($('.new_table',$table));
      } else {
        $subtable = $subtables.eq(i+1);
      }
      var nsrows = $('tbody tr',$subtable).length;
      target-= nsrows;
    }
    for(var i=0;i<$subtables.length;i++) {
      var $subtable = $subtables.eq(i+1);
      var nsrows = $('tbody tr',$subtable).length;
      if(nsrows < rows_per_subtable) {
        var to_add = target;
        if(to_add+nsrows > rows_per_subtable)
          to_add = rows_per_subtable - nsrows;
        var html = "";
        for(var j=0;j<to_add;j++) { html += row; }
        $subtable.append(html);
        target -= to_add;
      }
    }
  }

  function update_row2($table,data,row,columns) {
    var table_num = Math.floor(row/rows_per_subtable);
    var $subtable = $('table',$table).eq(table_num+1);
    var markup = $subtable.data('markup') || [];
    var idx = row-table_num*rows_per_subtable;
    markup[idx] = markup[idx] || [];
    di = 0;
    for(var i=0;i<columns.length;i++) {
      if(columns[i])
        markup[idx][i] = data[di++];
    }
    $subtable.data('markup',markup);
    return table_num;
  }

  function update_row3($table,row) {
    var table_num = Math.floor(row/rows_per_subtable);
    var $subtable = $('table',$table).eq(table_num+1);
    var markup = $subtable.data('markup') || [];
    var html = "";
    for(var i=0;i<markup.length;i++) {
      html += "<tr>";
      for(var j=0;j<markup[i].length;j++) {
        if(markup[i][j]) {
          html += "<td>"+(markup[i][j])+"</td>";
        } else {
          html += "<td></td>";
        }
      }
      html += "</tr>";
    }
    $('tbody',$subtable).html(html);
  }

  $.fn.new_table_tabular = function(config,data) {
    return {
      layout: function($table) {
        var config = $table.data('config');
        var header = new_header(config);
        return '<div class="new_table"><table>'+header+'<tbody></tbody></table></div>';
      },
      go: function($table,$el) {
        $('th',$table).click(function(e) {
          add_sort($table,$(this).data('key'),!e.shiftKey); 
        });
      },
      add_data: function($table,data,rows,columns) {
        console.log("add_data");
        extend_rows($table,rows);
        var subtabs = [];
        $.each(data,function(i,val) {
          subtabs[update_row2($table,val,i+rows[0],columns)]=1;
        });
        d = $.Deferred().resolve(subtabs);
        loop(d,function(tabnum,v) {
          console.log("updating table "+tabnum);
          update_row3($table,tabnum);
        },2,0);
      }
    };
  }; 

})(jQuery);
