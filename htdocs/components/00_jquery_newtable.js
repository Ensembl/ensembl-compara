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

  function make_chain(widgets,config) {
    config.pipes = [];
    $.each(widgets,function(key,widget) {
      if(widget.pipe) { config.pipes = config.pipes.concat(widget.pipe()); }
    });
  }

  function build_manifest(config,orient) {
    var incr_ok = true;
    var revpipe = [];
    var manifest = $.extend(true,{},orient);
    $.each(config.pipes,function(i,step) {
      var out = step(manifest);
      manifest = out[0];
      if(out[1]) { revpipe.push(out[1]); }
      if(!out[2]) { incr_ok = false; }
    });
    return [manifest,revpipe,incr_ok];
  }

  function build_orient(manifest_c,data) {
    var orient = $.extend(true,{},manifest_c[0]);
    $.each(manifest_c[1],function(i,step) {
      var out = step(orient,data);
      orient = out[0];
      data = out[1];
    });
    return [data,orient];
  }

  function manifest_subset(widgets,got,need) {
    if(!got) { return false; }
    need = $.extend(true,{},need);
    $.each(widgets,function(key,widget) {
      if(widget.subset) { need = widget.subset(got,need); }
    });
    return $.orient_compares_equal(got,need);
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

  function store_response_in_grid($table,rows,start,columns,manifest_in) {
    var grid = $table.data('grid') || [];
    var grid_manifest = $table.data('grid-manifest') || [];
    if(!$.orient_compares_equal(manifest_in,grid_manifest)) {
      console.log("clearing grid");
      grid = [];
      $table.data('grid-manifest',manifest_in);
    }
    $.each(rows,function (i,row) {
      var k = 0;
      $.each(columns,function(j,on) {
        if(on) {
          grid[start+i] = (grid[start+i]||[]);
          grid[start+i][j] = row[k++];
        }
      });
    });
    $table.data('grid',grid);
  }

  function render_grid(widgets,$table,manifest_c,start,length) {
    var view = $table.data('view');
    var grid = $table.data('grid');
    if(length==-1) { length = grid.length; }
    var orient_c = build_orient(manifest_c,grid);
    widgets[view.format].add_data($table,orient_c[0],start,length,orient_c[1]);
  }

  function rerender_grid(widgets,$table,manifest_c) {
    render_grid(widgets,$table,manifest_c,0,-1);
  }

  function use_response(widgets,$table,manifest_c,response) {
    store_response_in_grid($table,response.data,response.start,response.columns,manifest_c[0]);
    render_grid(widgets,$table,manifest_c,response.start,response.data.length);
  }
  
  function maybe_use_response(widgets,$table,result,config,manifest_c) {
    var cur_manifest = $table.data('manifest');
    var in_manifest = result.orient;
    var more = 0;
    if($.orient_compares_equal(cur_manifest,in_manifest)) {
      use_response(widgets,$table,manifest_c,result.response);
      if(result.response.more) {
        more = 1;
        get_new_data(widgets,$table,manifest_c,result.response.more,config);
      }
    }
    if(!more) { flux(widgets,$table,-1); }
  }

  function get_new_data(widgets,$table,manifest_c,more,config) {
    console.log("data changed, should issue request");
    if(more===null) { flux(widgets,$table,1); }
    console.log("get_new_data config",config);

    var payload_one = $table.data('payload_one');
    if(payload_one && $.orient_compares_equal(manifest_c[0],config.orient)) {
      $table.data('payload_one','');
      maybe_use_response(widgets,$table,payload_one,config,manifest_c);
    } else {
      $.get($table.data('src'),{
        orient: JSON.stringify(manifest_c[0]),
        more: JSON.stringify(more),
        config: JSON.stringify($table.data('config')),
        incr_ok: manifest_c[2]
      },function(res) {
        maybe_use_response(widgets,$table,res,config,manifest_c);
      },'json');
    }
  }

  function maybe_get_new_data(widgets,$table,config) {
    var old_manifest = $table.data('manifest');
    var orient = $.extend(true,{},$table.data('view'));
    $table.data('orient',orient);
    var manifest_c = build_manifest(config,orient);
    if($.orient_compares_equal(manifest_c[0],old_manifest)) {
      rerender_grid(widgets,$table,manifest_c);
    } else if(manifest_subset(widgets,old_manifest,manifest_c[0])) {
      rerender_grid(widgets,$table,manifest_c);
    } else {
      $table.data('manifest',manifest_c[0]);
      get_new_data(widgets,$table,manifest_c,null,config);
    }
  }

  var fluxion = 0;
  function flux(widgets,$table,state) {
    var change = -1;
    if(fluxion == 0 && state) { change = 1; }
    fluxion += state;
    if(fluxion == 0 && state) { change = 0; }
    if(change == -1) { return; }
    $.each(widgets,function(key,fn) {
      if(fn.flux) { fn.flux($table,change); }
    });
  }

  function new_table($target) {
    console.log('table',$target);
    var config = $.parseJSON($target.text());
    var widgets = make_widgets(config);
    make_chain(widgets,config);
    $.each(config.formats,function(i,fmt) {
      if(!config.orient.format && widgets[fmt]) {
        config.orient.format = fmt;
      }
    });
    if(config.orient.format === undefined) {
      console.error("No valid format specified for table");
    }
    if(config.orient.rows === undefined) {
      config.orient.rows = [0,-1];
    }
    if(config.orient.columns === undefined) {
      config.orient.columns = [];
      for(var i=0;i<config.columns.length;i++) {
        config.orient.columns.push(true);
      }
    }
    var $table = $('<div class="new_table_wrapper '+config.cssclass+'"><div class="topper"></div><div class="layout"></div></div>');
    $table.data('src',$target.attr('href'));
    $target.replaceWith($table);
    $('.topper',$table).html(new_top(widgets,config));
    var stored_config = {
      columns: config.columns,
      unique: config.unique,
      type: config.type
    };
    var view = $.extend(true,{},config.orient);
    var old_view = $.extend(true,{},config.orient);

    $table.data('view',view).data('old-view',$.extend(true,{},old_view))
      .data('config',stored_config);
    $table.data('payload_one',config.payload_one);
    build_format(widgets,$table);
//    $table.helptip();
    $table.on('view-updated',function() {
      var view = $table.data('view');
      var old_view = $table.data('old-view');
      console.log('updated',old_view,view);
      if(view.format != old_view.format) {
        build_format(widgets,$table);
      }
      maybe_get_new_data(widgets,$table,config);
      $table.data('old-view',$.extend(true,{},view));
    });
    $('div[data-widget-name]',$table).each(function(i,el) {
      var $widget = $(el);
      var name = $widget.attr('data-widget-name');
      if($widget.hasClass('_inited')) { return; }
      $widget.addClass('_inited');
      widgets[name].go($table,$widget);
    });
    maybe_get_new_data(widgets,$table,config);
  }

  $.orient_compares_equal = function(fa,fb) {
    if(fa===fb) { return true; }
    if(!$.isPlainObject(fa) && !$.isArray(fa)) { return false; }
    if(!$.isPlainObject(fb) && !$.isArray(fb)) { return false; }
    if($.isArray(fa)?!$.isArray(fb):$.isArray(fb)) { return false; }
    var good = true;
    $.each(fa,function(idx,val) {
      if(!$.orient_compares_equal(fb[idx],val)) { good = false; }
    });
    $.each(fb,function(idx,val) {
      if(!$.orient_compares_equal(fa[idx],val)) { good = false; }
    });
    return good;
  };

  $.fn.newTable = function() {
    this.each(function(i,outer) {
      new_table($(outer));
    });
    return this;
  }; 

})(jQuery);
