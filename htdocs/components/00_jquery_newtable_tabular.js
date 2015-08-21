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

  function new_th(index,colconf) {
    var text = colconf.label || colconf.title || colconf.key;
    var attrs = {};
    var classes = [];
    attrs['data-key'] = colconf.key || '';
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

  // TODO fix widths on load
  // TODO initial orient
  function fix_widths($table,config,orient) {
    var totals = { u: 0, px: 0 };
    var widths = [];
    $.each(config.columns,function(i,data) {
      var m = data.width.match(/^(\d+)(.*)$/)
      widths.push([m[1],m[2]]);
      if(orient.columns[i]) {
        if(data.width[1] == 'u' || data.width[1] == 'px') {
          totals[data.width[1]] += parseInt(data.width[0]);
        }
      }
    });
    console.log("widths",totals);
    var table_width = $table.width();
    totals['px'] *= 100/table_width;
    if(totals['px'] > 100) { totals['px'] = 100; }
    totals['u'] = (100-totals['px']) / (totals['u']||1);
    console.log("widths2",totals);
    var $head = $('table:first th',$table);
    $head.each(function(i) {
      if(orient.columns[i]) {
        $(this).css('width',(widths[i][0]*totals[widths[i][1]])+"%");
      }
    });
  }

  function new_header($table,config) {
    var columns = [];

    $.each(config.columns,function(i,data) {
      columns.push(new_th(i,data));
    });
    return '<thead><tr>'+columns.join('')+"</tr></thead>";
  }
 
  function header_fix($table,orient) {
    console.log("header_fix ori:",orient.columns);
    var $th = $('th',$table);
    $.each(orient.columns,function(i,v) {
      var $h = $th.eq(i);
      if(v) { $h.show(); } else { $h.hide(); }
    });
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
    return $('<div class="subtable"><table><tbody></tbody></table></div>');
  }

  function extend_rows($table,target) {
    console.log("extend_rows");
    var $subtables = $('.subtable',$table);
    target -= $subtables.length*rows_per_subtable;
    while(target > 0) {
      var $subtable = new_subtable($table).appendTo($('.new_table',$table));
      var to_add = target;
      if(to_add > rows_per_subtable)
        to_add = rows_per_subtable;
      target -= to_add;
    }
    console.log("/extend_rows");
  }

  function update_row2($table,grid,row,orient) {
    var table_num = Math.floor(row/rows_per_subtable);
    var $subtable = $('.subtable',$table).eq(table_num);
    var markup = $subtable.data('markup') || [];
    var idx = row-table_num*rows_per_subtable;
    markup[idx] = markup[idx] || [];
    for(var i=0;i<grid[row].length;i++) {
      markup[idx][i] = (grid[row][i]||[''])[0];
    }
    $subtable.data('markup',markup);
    $subtable.data('markup-orient',orient);
    return table_num;
  }

  function build_html($table,table_num,orient) {
    var $subtable = $('.subtable',$table).eq(table_num);
    var $th = $('table:first th',$table);
    var markup = $subtable.data('markup') || [];
    var html = "";
    for(var i=0;i<markup.length;i++) {
      html += "<tr>";
      for(var j=0;j<$th.length;j++) {
        if(!orient.columns[j]) { continue; }
        var start = "<td>";
        if(i==0) {
          start = "<td style=\"width: "+$th.eq(j).width()+"px\">";
        }
        if(markup[i][j]) {
          html += start+markup[i][j]+"</td>";
        } else {
          html += start+"</td>";
        }
      }
      html += "</tr>";
    }
    return html;
  }

  function apply_html($table,table_num,html) {
    var $subtable = $($('.subtable',$table).eq(table_num));
    var $body = $('tbody',$subtable);
    if(!$body.length) {
      var $newtable = new_subtable();
      $subtable.replaceWith($newtable);
      $subtable = $newtable;
    }
    $('tbody',$subtable)[0].innerHTML = html;
    // The line below is probably more portable than the line above,
    //   but a third of the speed.
    //   Maybe browser checks if there are compat issues raised in testing?
    // $('tbody',$subtable).html(html);
    $subtable.css('height',$('table',$subtable).css('height'));
    return $subtable;
  }

  function set_active_orient($subtable,active_orient) {
    var our_orient = $subtable.data('markup-orient');

    if(!$.orient_compares_equal(active_orient,our_orient)) {
      $subtable[0].innerHTML = '';
    }
  }

  function replace_header($table,header) {
    $('thead',$table).replaceWith(header);
  }

  $.fn.new_table_tabular = function(config,data) {
    return {
      layout: function($table) {
        var config = $table.data('config');
        var header = new_header($table,config);
        return '<div class="new_table"><table>'+header+'<tbody></tbody></table></div>';
      },
      go: function($table,$el) {
        $('th',$table).click(function(e) {
          add_sort($table,$(this).data('key'),!e.shiftKey); 
        });
      },
      add_data: function($table,grid,start,num,orient) {
        var $subtables = $('.subtable',$table);
        $subtables.each(function() {
          set_active_orient($(this),orient);
        });
        var config = $table.data('config');
        fix_widths($table,config,orient);
        console.log("add_data orient",orient);
        header_fix($table,orient);
        extend_rows($table,start+num);
        var subtabs = [];
        for(var i=0;i<num;i++) {
          subtabs[update_row2($table,grid,i+start,orient)]=1;
        }
        d = $.Deferred().resolve(subtabs);
        loop(d,function(tabnum,v) {
          var html = build_html($table,tabnum,orient);
          var $subtable = apply_html($table,tabnum,html);
          // XXX have generic decoration method
          if($.fn.togglewrap) {
            $subtable.togglewrap();
          }
        },1,100);
      }
    };
  }; 

})(jQuery);
