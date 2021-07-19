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

  function obj_empty(x) {
    for(var k in x) {
      if(x.hasOwnProperty(k)) { return false; }
    }
    return true;
  }

  $.fn.new_table_filter = function(config,data,widgets) {

    var filterable_columns = {};

    function find_widget(wanted_name,type,def) {
      var w;
      $.each(widgets,function(name,contents) {
        if(contents[type]) {
          for(var i=0;i<contents[type].length;i++) {
            if(contents[type][i].name == wanted_name) {
              w = contents[type][i];
            }
          }
        }
      });
      if(w) { return w; }
      if(def!==null) { return find_widget(def,type,null); }
      return null;
    }

    function dropdown(idx,filter,label,primary) {
      var prec = primary?"pri":"sec";
      var ht_text = "Filter table rows by "+label+".";
      if(filter=='') {
        filter = 'more';
        ht_text = "Filter by other columns.";
      }
      var out = '<li class="t prec_'+prec+'" data-idx="'+idx+'"><div class="x"><span></span></div><div class="b"><span class="k _ht">'+label+'</span><span class="v _ht">All</span><div class="m newtable_filtertype_'+filter+'" data-filter="'+filter+'">'+label+'</div></div></li>';
      var $x = $('<div/>');
      $x.append($(out)).find('.b ._ht').attr('title',ht_text);
      return $x.html();
    }

    function activate_menu($table,$button,others_only) {
      var $el = $button.find('.m');
      $('.newtable_filter li .m:visible').each(function() {
        if($el.length && $el[0] == this) { return; }
        hide_menu($(this));
      });
      if($button.length && !others_only) {
        if(!$el.is(":visible")) {
          menu($table,$button,$el);
          show_menu($el);
        } else {
          hide_menu($el);
        }
      }
    }
    
    function maybe_hide_more($table,$out) {
      if(!$('.newtable_filter .prec_sec',$table).length) {
        $table.find('.more').hide();
      }
    }

    function activate_sec($item) {
      var $table = $item.closest('.new_table_wrapper');
      if(!$item.hasClass('prec_sec')) { return; }
      $item.removeClass('prec_sec').addClass('prec_pri');
      maybe_hide_more($table);
    }

    function draw_more($table,$menu) {
      var $out = $("<ul/>");
      $('.newtable_filter .prec_sec',$table).each(function() {
        var $item = $(this);
        var $li = $("<li/>").text($('.k',$item).text()).appendTo($out);
        $li.on('click',function(e) {
          activate_sec($item);
          activate_menu($table,$item,false);
        });
      });
      $menu.empty().append($out);
    }

    function add_ok_cancel($tail,$table,$button,replace) {
      var $ul = $('<ul/>').appendTo($tail);
      var $ok = $('<li/>').html("Apply &raquo;").addClass('apply').appendTo($ul);
      if(!replace) { $ok.addClass('unchanged'); }
      $tail.closest('.m').on('okable',function(e,yn) {
        $ok.toggleClass('unchanged',yn?false:true);
      });
      $ok.click(function() {
        if($(this).hasClass('unchanged')) { return; }
        hide_menu($tail.closest('.m'));
        update_state($table,$button,$button.data('filter-state'));
        update_button($table,$button);
        $table.trigger('view-updated');
      });
      var $cancel = $('<li/>').text("Cancel").addClass('cancel').appendTo($ul);
      $cancel.click(function() {
        hide_menu($tail.closest('.m'));
      });
    }

    function menu($table,$button,$menu) {
      var idx = $button.data('idx');
      if(idx==-1) {
        draw_more($table,$menu);
        return;
      }
      var key = config.columns[idx];
      var state = (($table.data('view').filter||{})[key])||{};
      var kind = config.colconf[key].range;
      var vals = ($table.data('ranges')||{})[key];
      if(!vals) { vals = []; }
      var km = $table.data('keymeta').filter;
      if(km) { km = km[key]; }
      var w = find_widget(kind,'filters','class');
      var $box = $('<div/>');
      $menu.empty().append($box);
      var $head = $('<div class="head"/>').appendTo($box);
      var cc = config.colconf[key];
      var title = (cc.filter_label || cc.label || cc.title || key);
      $('<div class="title"/>').appendTo($head).html(title);
      $summary = $('<div class="summary"/>').html("&#x00A0;").appendTo($head);
      var $smore = $('<div class="more"/>').text('more rows pending').appendTo($summary);
      $table.on('flux-load',function(e,onoff) { $smore.toggle(onoff); });
      $table.trigger('flux-update',['load']);
      if($('.new_table_loading:visible',$table).length) {
      }
      $stext = $('<div class="summary_text"/>').html("&#x00A0;").appendTo($summary);
      if(w.visible(vals)) {
        var replace = !!($button.find('.m:visible').length);
        var replace_state = $button.data('filter-state');
        if(replace && replace_state!==undefined) { state = replace_state; }
        w.display($box,$button,vals,state,km,key,$table);
        var $tail = $('<div class="tail"/>').appendTo($box);
        add_ok_cancel($tail,$table,$button,replace);
      } else {
        $('<div/>').addClass('none_present').text('None present').appendTo($box);
      }
    }

    function show_or_hide_all($table) {
      var $filters = $('.newtable_filter',$table);
      var $vbuts = $('.t',$filters);
      $filters.toggle(!!$vbuts.length);
      maybe_hide_more($table);
    }

    function unrestrict(config,$el,view) {
      var key = config.columns[$el.closest('li').data('idx')];
      if(view.filter && view.filter.hasOwnProperty(key)) {
        delete view.filter[key];
      }
      if(obj_empty(view.filter)) { delete view.filter; }
    }

    function set_button($el,view,w,key,values,km) {
      if((view.filter||{}).hasOwnProperty(key)) {
        var text = w.text(view.filter[key],values,km);
        $('.v',$el).text(text);
        $el.addClass('restricted');
        activate_sec($el);
      } else {
        $('.v',$el).text('All');
        $el.removeClass('restricted');
      }
    }

    function update_button($table,$el) {
      var view = $table.data('view');
      var idx = $el.data('idx');
      if(idx==-1) { // More button
        $el.addClass('more');
      } else { // Not more button
        var key = config.columns[idx];
        var km = ($table.data('keymeta')||{}).filter;
        if(km) { km = km[key]; }
        var values = ($table.data('ranges')||{})[key]||{};
        var kind = config.colconf[key].range;
        var w = find_widget(kind,'filters','class');
        set_button($el,view,w,key,values,km);
        show_or_hide_all($table);
      }
      var $menu = $('.m',$el);
      if($menu.length && $menu.is(":visible")) {
        show_menu($menu);
      }
    }

    function update_state($table,$el,state) {
      var view = $table.data('view');
      if(!view.filter) { view.filter = {}; }
      var idx = $el.data('idx');
      var key = config.columns[idx];
      if(obj_empty(state)) {
        delete view.filter[key];
      } else {
        view.filter[key] = state;
      }
      if(obj_empty(view.filter)) { delete view.filter; }
      $table.data('view',view);
    }

    function show_menu($el) {
      $el.closest('.b').find('._ht:data(ui-tooltip)').helptip('close');
      $el.show();
      var right = $el.offset().left+$el.width();
      if(right>$('html').width()) {
        $el.css("left",($('html').width()-right-8)+"px");
      }
    }

    function hide_menu($el) {
      $el.hide();
    }

    function add_blanks(value,column,plugin,keymeta) {
      $.each(keymeta,function(klass,klassdata) {
        $.each(klassdata,function(col,coldata) {
          if(col == column) {
            plugin.value(value,null,0);
          }
        });
      });
    }

    function add_from_keymeta(value,column,plugin,keymeta) {
      $.each(keymeta,function(klass,klassdata) {
        $.each(klassdata,function(col,coldata) {
          if(col == column) {
            $.each(coldata,function(val,valdata) {
              if(val != '*') { plugin.value(value,val,0); }
            });
          }
        });
      });
    }

    function eundo(client_enums,enums,grid,series,keymeta) {
      for(var i=0;i<series.length;i++) {
        var plugin = client_enums[series[i]];
        var star = undefined;
        if(keymeta && keymeta.enumerate && keymeta.enumerate[series[i]]) {
          star = keymeta.enumerate[series[i]]['*'];
        }
        if(!plugin) {
          /* Can't merge, so hope we have a range */
          if(star && star.merge) { enums[series[i]] = star.merge; }
          continue;
        }
        var value = {};
        if(star) {
          /* Populate from keymeta values */
          if(star.from_keymeta) {
            add_from_keymeta(value,series[i],plugin,keymeta);
          }
          /* Populate from keymeta merge */
          if(star.merge) {
            value = plugin.merge(value,star.merge);
          }
        }
        var fstar = undefined;
        if(keymeta && keymeta.filter && keymeta.filter[series[i]]) {
          fstar = keymeta.filter[series[i]]['*'];
        }
        if(fstar && fstar.maybe_blank) {
          add_blanks(value,series[i],plugin,keymeta);
        }
        /* Populate by each value */
        for(var j=0;j<grid.length;j++) {
          var v = grid[j][i];
          if(v===undefined) { continue; }
          if(plugin.split && v!==null) { v = plugin.split(v); }
          else { v = [v]; }
          if(v===undefined || v===null) { continue; }
          for(var k=0;k<v.length;k++) {
            plugin.value(value,v[k],1);
          }
        }
        if(plugin.finish) { value = plugin.finish(value,series[i],keymeta); }
        enums[series[i]] = value;
      }
      return enums;
    }

    function build_client_filter(out,need,got) {
      out.undo = function(manifest,grid,series,dest) {
        delete manifest.enumerate;
        return [manifest,grid];
      };
      var needf = (need||{}).filter || {};
      var gotf = (got||{}).filter || {};
      var to_filter = {};
      $.each(needf,function(col,v) {
        to_filter[col]=1;
      });
      var ok = 1;
      $.each(gotf,function(col,v) {
        if(!to_filter.hasOwnProperty(col)) {
          ok = 0; // Unwanted filter, can't undo that on the client
        }
      });
      if(!ok) { return null; }
      var n = 0;
      $.each(to_filter,function(col,v) {
        var cc = config.colconf[col];
        if(cc) {
          var cf = $.find_type(widgets,cc);
          if(cf && cf.match) {
            to_filter[col] = cf;
            n++;
          } else {
            ok = 0;
          }
        } else { // filter not in present table
          to_filter[col] = null;
          n++;
        }
      });
      if(!ok || !n) { return null; }
      var colidx = {};
      $.each(to_filter,function(col,v) {
        for(var i=0;i<config.columns.length;i++) {
          if(config.columns[i] == col) { colidx[col] = i; }
        }
      });
      out.undo = function(manifest,grid,series,dest) {
        delete manifest.enumerate;
        var rev_series = {};
        for(var i=0;i<series.length;i++) { rev_series[series[i]] = i; }
        var fabric = [];
        for(var i=0;i<grid.length;i++) {
          var ok = true;
          $.each(to_filter,function(col,fn) {
            if(fn===null) { return; } // filter not in present table
            var v = grid[i][rev_series[col]];
            if(v===null || v===undefined) {
              v = [v];
            } else {
              if(fn.split) { v = fn.split(v); } else { v = [v]; }
            }
            var ok_col = false;
            for(var j=0;j<v.length;j++) {
              if(fn.match(needf[col],v[j])) { ok_col = true; break; }
            }
            if(!ok_col) { ok = false; }
          });
          if(ok) {
            fabric.push(grid[i]);
          }
        }
        manifest.filter = needf;
        return [manifest,fabric];
      };
      out.all_rows = true;
      delete need.filter;
    }

    function add_button(idx,key) {
      var cc = config.colconf[key];
      if(!cc.range) { return ""; }
      var label = "";
      var label = cc.filter_label || cc.label || key;
      if(!cc.range) { return ""; }
      filterable_columns[key] = cc;
      return dropdown(idx,cc.range,label,cc.primary);
    }

    return {
      generate: function() {
        var dropdowns = "";
        var all_dropdowns = [];
        $.each(config.columns,function(i,key) {
          var cc = config.colconf[key];
          all_dropdowns.push([cc.primary,i,add_button(i,key)]);
        });
        all_dropdowns.sort(function(a,b) {
          if(a[0]) { if(b[0]) { return a[0]-b[0]; } else { return -1; } }
          if(b[0]) { return 1; } else { return a[1]-b[1]; }
        });
        $.each(all_dropdowns,function(i,val) {
          dropdowns += val[2];
        });
        dropdowns += dropdown(-1,'','Filter Other Columns',true);

        var out='<div class="newtable_filter"><span class="intro">Filter</span><ul>'+dropdowns+'</ul></div>';
        return out;
      },
      position: data.position,
      go: function($table,$el) {
        $('li.t',$el).on('update',function(e,state) {
          $(this).data('filter-state',state);
          $(this).find('.apply').removeClass('unchanged');
        });
        $table.on('range-updated',function(e) {
          $('li.t',$el).each(function() {
            var $button = $(this);
            update_button($table,$button);
            var $menu = $('.m',$button);
            if($menu.is(':visible')) {
              menu($table,$button,$menu);
              show_menu($menu);
            }
          });
        });
        $('.x',$el).on('click',function(e) {
          var view = $table.data('view');
          unrestrict(config,$(this),view);
          $table.data('view',view);
          $table.trigger('view-updated');
          var $button = $(this).closest('li');
          update_button($table,$button);
          $('.newtable_filter li .m:visible',$el).each(function() {
            hide_menu($(this));
          });
          e.stopPropagation();
        });
        $('li.t',$el).each(function() { update_button($table,$(this)); });
        $('html').on('click',function(e) {
          if(!$table.closest('html').length) { return; }
          var $button = $(e.target).closest('.newtable_filter li.t');
          var $menu = $(e.target).closest('.newtable_filter li.t .m');
          activate_menu($table,$button,!!$menu.length);
        });
        $('.b ._ht',$el).helptip();
      },
      pipe: function() {
        return [
          function(need,got) {
            var server_filter = [];
            var client_enums = {};
            $.each(filterable_columns,function(key,cc) {
              var cf = $.find_type(widgets,cc);
              if(cf) {
                client_enums[key] = cf;
              } else {
                server_filter.push(key);
              }
            });
            if(server_filter.length) {
              need.enumerate = server_filter;
            } else {
              delete need.enumerate;
            }
            var out = {
              eundo: function(enums,grid,series,keymeta) {
                return eundo(client_enums,enums,grid,series,keymeta);
              }
            };
            if(obj_empty(need.filter)) { delete need.filter; }
            build_client_filter(out,need,got);
            return out;
          }
        ];
      }
    };
  }; 

})(jQuery);
