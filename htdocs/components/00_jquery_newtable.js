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
  function make_widget(config,widget) {
    var data = {};
    if($.isArray(widget)) {
      data = widget[1];
      widget = widget[0];
    }
    if(!$.isFunction($.fn[widget])) {
      return null;
    }
    return $.fn[widget](config,data);
  }

  function make_widgets(config) {
    var widgets = {};
    $.each(config.widgets,function(key,name) {
      var data = {};
      if($.isArray(name)) {
        data = name[1];
        name = name[0];
      }
      if($.isFunction($.fn[name])) {
        widgets[key] = $.fn[name](config,data);
      }
    });
    return widgets;
  }

  function new_top_section(widgets,config,pos) {
    var content = '';
    $.each(config.head[pos],function(i,widget) {
      if(widget && widgets[widget]) {
        content +=
          '<div data-widget-name="'+widget+'">'+
            widgets[widget].generate()+
          '</div>';
      }
    });
    if(pos==1) { content = '<div>'+content+'</div>'; }
    return content;
  }

  function new_top(widgets,config) {
    var ctrls = "";
    for(var pos=0;pos<3;pos++) {
      ctrls += '<div class="new_table_section new_table_section_'+pos+'">'
               + new_top_section(widgets,config,pos) +
               '</div>';
    }

    return '<div class="new_table_top">'+ctrls+'</div>';
  }
    
  function build_format(widgets,$table) {
    var view = $table.data('view');
    console.log("build_format '"+view.format+"'");
    $('.layout',$table).html(
      '<div data-widget-name="'+view.format+'">'+
      widgets[view.format].layout($table)+"</div>"
    );
    var $widget = $('div[data-widget-name='+view.format+']',$table);
    if($widget.hasClass('_inited')) { return; }
    $widget.addClass('_inited');
    widgets[view.format].go($table,$widget);
  }

  function compares_equal(fa,fb) {
    if(fa===fb) { return true; }
    if(!$.isPlainObject(fa) && !$.isArray(fa)) { return false; }
    if(!$.isPlainObject(fb) && !$.isArray(fb)) { return false; }
    if($.isArray(fa)?!$.isArray(fb):$.isArray(fb)) { return false; }
    var good = true;
    $.each(fa,function(idx,val) {
      if(fb[idx] != val) { good = false; }
    });
    $.each(fb,function(idx,val) {
      if(fa[idx] != val) { good = false; }
    });
    return good;
  }

  function use_response(widgets,$table,data) {
    var view = $table.data('view');
    widgets[view.format].add_data(data.data,
                                  data.region.rows,
                                  data.region.columns);
  }

  function eliminate_one(base,elim) {
    var out = []; 
    if((base[1] != -1 && elim[0] >= base[1]) ||                 
       (elim[1] != -1 && elim[1] <= base[0])) {
      out.push(base);
    } else {
      if(elim[0] > base[0]) {
        out.push([base[0],elim[0],base[2]]);
      }   
      if((elim[1] < base[1] || base[1] == -1) && elim[1] != -1) {
        out.push([elim[1],base[1],base[2]]);
      }
      var a = elim[0];
      var b = elim[1];
      if(a < base[0]) { a = base[0]; }
      if(base[1] != -1 && b > base[1]) { b = base[1]; }
      if(b > a || b == -1) {
        var newset = [];
        var any = false;
        for(var i=0;i<base[2].length;i++) {
          newset[i] = base[2][i] && !elim[2][i];
          any = (any || newset[i]);
        }
        if(any) {
          out.push([a,b,newset]);
        }
      } 
    }
    return out;
  }

  function eliminate(bases,elims) {
    for(var i=0;i<elims.length;i++) {
      var out = []; 
      for(var j=0;j<bases.length;j++) {
        out = out.concat(eliminate_one(bases[j],elims[i]));
      }   
      bases = out;
    }
    return out;
  }
  
  function maybe_issue_followon(widgets,$table,data,req,res) {
    // two convenience functions for converting format
    function r2a(r) { return [r.rows[0],r.rows[1],r.columns]; }
    function a2r(a) { return { rows: [a[0],a[1]], columns: a[2] }; }

    var all_cols = [];
    var all_with_data = [];
    $.each(req,function(i,r) { all_cols.push(r2a(r)); });
    $.each(res,function(i,r) { all_with_data.push(r2a(r)); });
    var remaining = eliminate(all_cols,all_with_data);
    var outstanding = [];
    $.each(remaining,function(i,r) { outstanding.push(a2r(r)); });
    if(outstanding.length) {
      get_new_data(widgets,$table,data,outstanding);
    }
  }

  function maybe_use_response(widgets,$table,result) {
    var cur_data = $table.data('data');
    var in_data = result.data;
    if(compares_equal(cur_data,in_data)) {
      var got = [];
      $.each(result.response,function(i,data) {
        use_response(widgets,$table,data);
        got.push(data.region);
      });
      maybe_issue_followon(widgets,$table,in_data,result.regions,got);
    }
  }

  function get_new_data(widgets,$table,data,regions) {
    console.log("data changed, should issue request");
    $.get($table.data('src'),{
      data: JSON.stringify(data),
      regions: JSON.stringify(regions)
    },function(res) {
      maybe_use_response(widgets,$table,res);
    },'json');
  }

  function maybe_get_new_data(widgets,$table) {
    var old_data = $table.data('old-data');
    var view = $table.data('view');
    var data = $.extend(true,{},view);
    delete data.columns;
    delete data.rows;
    delete data.format;
    $table.data('data',data);
    if(!compares_equal(data,old_data)) {
      get_new_data(widgets,$table,data,[{
        columns: view.columns,
        rows: view.rows
      }]);
    }
    $table.data('old-data',data);
  }

  function new_table($target) {
    console.log('table',$target);
    var config = $.parseJSON($target.text());
    var widgets = make_widgets(config);
    $.each(config.formats,function(i,fmt) {
      if(!config.view.format && widgets[fmt]) {
        config.view.format = fmt;
      }
    });
    if(config.view.format === undefined) {
      console.error("No valid format specified for table");
    }
    if(config.view.rows === undefined) {
      config.view.rows = [0,-1];
    }
    if(config.view.columns === undefined) {
      config.view.columns = [];
      for(var i=0;i<config.columns.length;i++) {
        config.view.columns.push(true);
      }
    }
    var $table = $('<div class="new_table_wrapper"><div class="topper"></div><div class="layout"></div></div>');
    $('.topper',$table).html(new_top(widgets,config));
    var stored_config = { columns: config.columns };
    $table.data('view',config.view).data('old-view',$.extend(true,{},config.view))
      .data('config',stored_config);
    build_format(widgets,$table);
//    $table.helptip();
    $table.on('view-updated',function() {
      var view = $table.data('view');
      var old_view = $table.data('old-view');
      console.log('updated',old_view,view);
      if(view.format != old_view.format) {
        build_format(widgets,$table);
      }
      maybe_get_new_data(widgets,$table);
      $table.data('old-view',$.extend(true,{},view));
    });
    $('div[data-widget-name]',$table).each(function(i,el) {
      var $widget = $(el);
      var name = $widget.attr('data-widget-name');
      if($widget.hasClass('_inited')) { return; }
      $widget.addClass('_inited');
      widgets[name].go($table,$widget);
    });
    $table.data('src',$target.attr('href'));
    maybe_get_new_data(widgets,$table);
    $target.replaceWith($table);
  }

  $.fn.newTable = function() {
    this.each(function(i,outer) {
      new_table($(outer));
    });
    return this;
  }; 

})(jQuery);
