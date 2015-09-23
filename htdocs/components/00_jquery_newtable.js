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
    var types = {};
    $.each(config.widgets,function(key,name) {
      var data = {};
      if($.isArray(name)) {
        data = name[1];
        name = name[0];
      }
      if($.isFunction($.fn[name])) {
        widgets[key] = $.fn[name](config,data,widgets);
      }
    });
    return widgets;
  }

  function build_frame(config,widgets,$html) {
    /* Build full list of slots and construct frame */
    full_frame = {};
    cwidgets = [];
    tags = {};
    $.each(widgets,function(key,widget) { cwidgets.push(key); });
    cwidgets.sort(function(a,b) { return (widgets[a].prio||50)-(widgets[b].prio||50); });
    $.each(cwidgets,function(i,key) {
      var widget = widgets[key];
      if(widget.frame) {
        var out = widget.frame($html);
        $.each(out,function(name,details) {
          if(name=='$') { return; }
          details.name = name;
          details.widget = widget;
          full_frame[key+'--'+name] = details;
          for(var i=0;i<details.tags.length;i++) {
            if(!tags[details.tags[i]]) { tags[details.tags[i]] = []; }
            tags[details.tags[i]].push(details);
          }
        });
        $html = out['$'];
      }
    });
    /* Survey for those that need a position */
    var candidates = {};
    $.each(cwidgets,function(i,key) {
      var widget = widgets[key];
      if(widget.position) {
        var position = null;
        for(var i=0;i<widget.position.length;i++) {
          if(!tags.hasOwnProperty(widget.position[i])) { continue; }
          var slots = tags[widget.position[i]];
          if(!candidates[slots[0].name]) { candidates[slots[0].name] = []; }
          candidates[slots[0].name].push([key,widget,slots[0]]);
          slots.push(slots.shift());
          break;
        }
      }
    });
    /* Go for each position */
    $.each(candidates,function(pos,widgets) {
      var ww = widgets.slice();
      ww.sort(function(a,b) { return (b[1].position_order||50)-(a[1].position_order||50); });
      for(var i=0;i<ww.length;i++) {
        var $widget = $('<div data-widget-name="'+ww[i][0]+'"/>');
        $widget.append(ww[i][1].generate);
        $widget = $('<div/>').append($widget);
        ww[i][2]['$'].append($widget);
      } 
    });
    return $html;
  }

  function make_chain(widgets,config,$table) {
    config.pipes = [];
    cwidgets = [];
    $.each(widgets,function(key,widget) { cwidgets.push(widget); });
    cwidgets.sort(function(a,b) { return (a.prio||50)-(b.prio||50); });
    $.each(cwidgets,function(key,widget) {
      if(widget.pipe) { config.pipes = config.pipes.concat(widget.pipe($table)); }
    });
  }

  function build_manifest(config,orient,target) {
    var incr = true;
    var all_rows = false;
    var revpipe = [];
    var erevpipe = [];
    var wire = {};
    var manifest = $.extend(true,{},orient);
    $.each(config.pipes,function(i,step) {
      var out = step(manifest,target,wire);
      if(out) {
        if(out.manifest) { manifest = out.manifest; }
        if(out.undo) { revpipe.push(out.undo); }
        if(out.eundo) { erevpipe.push(out.eundo); }
        if(out.no_incr) { incr = false; }
        if(out.all_rows) { all_rows = true; }
      }
    });
    return { manifest: manifest, undo: revpipe, eundo: erevpipe, wire: wire,
             incr_ok: incr, all_rows: all_rows };
  }

  function build_orient(manifest_c,data,data_series,destination) {
    var orient = $.extend(true,{},manifest_c.manifest);
    $.each(manifest_c.undo,function(i,step) {
      var out = step(orient,data,data_series,destination);
      orient = out[0];
      data = out[1];
    });
    return { data: data, orient: orient };
  }

  function build_enums(manifest_c,grid,series,enums) {
    $.each(manifest_c.eundo,function(i,step) {
      enums = step(enums,grid,series);
    });
    return enums;
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

  function build_series_index($table,series) {
    var fwd = $table.data('grid-series') || [];
    var rev = {};
    for(var i=0;i<fwd.length;i++) { rev[fwd[i]] = i; }
    for(var i=0;i<series.length;i++) {
      if(rev.hasOwnProperty(series[i])) { continue; }
      rev[series[i]] = fwd.length;
      fwd.push(series[i]);
    }
    $table.data('grid-series',fwd);
    var out = [];
    for(var i=0;i<series.length;i++) {
      out.push(rev[series[i]]);
    }
    return out;
  }

  function store_response_in_grid($table,rows,start,manifest_in,series) {
    var grid = $table.data('grid') || [];
    var grid_manifest = $table.data('grid-manifest') || [];
    var indexes = build_series_index($table,series);
    console.log('indexes',series,indexes);
    if(!$.orient_compares_equal(manifest_in,grid_manifest)) {
      console.log("clearing grid");
      grid = [];
      $table.data('grid-manifest',manifest_in);
    }
    $.each(rows,function (i,row) {
      for(var k=0;k<row.length;k++) {
        grid[start+i] = (grid[start+i]||[]);
        grid[start+i][indexes[k]] = row[k]; 
      }
    });
    $table.data('grid',grid);
  }

  function store_ranges($table,enums,cur_manifest,manifest_in,config,widgets) {
    var grid = $table.data('grid') || [];
    var series = $table.data('grid-series') || [];
    var enums = build_enums(cur_manifest,grid,series,enums) || {};
    var ranges = $table.data('ranges') || {};
    var range_manifest = $table.data('range-manifest') || [];
    if(!$.orient_compares_equal(manifest_in,range_manifest)) {
      console.log("clearing ranges",manifest_in,range_manifest);
      ranges = {};
      $table.data('range-manifest',manifest_in);
    }
    $.each($table.data('range-fixed'),function(k,v) {
      if(!ranges[k]) { ranges[k] = v.slice(); }
    });
    $.each(enums,function(column,range) {
      var fn = $.find_type(widgets,config.colconf[column]).merge;
      ranges[column] = fn(ranges[column],range);
    });
    $table.data('ranges',ranges);
    $table.trigger('range-updated');
  }

  function store_keymeta($table,incoming) {
    var keymeta = $table.data('keymeta') || {};
    $.each(incoming||{},function(key,indata) {
      if(!keymeta[key]) { keymeta[key] = {}; }
      $.each(indata,function(k,v) {
        if(!keymeta[key].hasOwnProperty(k)) { keymeta[key][k] = v; }
      });
    });
    $table.data('keymeta',keymeta);
  }

  function render_grid(widgets,$table,manifest_c,start,length) {
    var view = $table.data('view');
    var grid = $table.data('grid');
    var grid_series = $table.data('grid-series');
    if(length==-1) { length = grid.length; }
    var orient_c = build_orient(manifest_c,grid,grid_series,view);
    if(manifest_c.all_rows) {
      start = 0;
      length = orient_c.data.length;
    }
    widgets[view.format].add_data($table,orient_c.data,grid_series,start,length,orient_c.orient);
    widgets[view.format].truncate_to($table,length,orient_c[1]);
  }

  function rerender_grid(widgets,$table,manifest_c) {
    render_grid(widgets,$table,manifest_c,0,-1);
  }

  function use_response(widgets,$table,manifest_c,response,config) {
    store_response_in_grid($table,response.data,response.start,manifest_c.manifest,response.series);
    render_grid(widgets,$table,manifest_c,response.start,response.data.length);
    store_ranges($table,response.enums,manifest_c,response.shadow,config,widgets);
  }
  
  function maybe_use_response(widgets,$table,result,config) {
    store_keymeta($table,result.response.keymeta);
    var cur_manifest = $table.data('manifest');
    var in_manifest = result.orient;
    var more = 0;
    if($.orient_compares_equal(cur_manifest.manifest,in_manifest)) {
      use_response(widgets,$table,cur_manifest,result.response,config);
      if(result.response.more) {
        more = 1;
        get_new_data(widgets,$table,cur_manifest,result.response.more,config);
      }
    }
    if(!more) { flux(widgets,$table,'load',-1); }
  }

  function extract_params(url) {
    var out = {};
    var parts = url.split('?',2);
    if(parts.length<2) { return out; }
    var kvs = parts[1].split(';');
    for(var i=0;i<kvs.length;i++) {
      var kv = kvs[i].split('=');
      out[kv[0]] = kv[1];
    }
    return out;
  }

  function get_new_data(widgets,$table,manifest_c,more,config) {
    console.log("data changed, should issue request");
    if(more===null) { flux(widgets,$table,'load',1); }

    var payload_one = $table.data('payload_one');
    if(payload_one && $.orient_compares_equal(manifest_c.manifest,config.orient)) {
      $table.data('payload_one','');
      maybe_use_response(widgets,$table,payload_one,config);
    } else {
      wire_manifest = $.extend({},manifest_c.manifest,manifest_c.wire);
      src = $table.data('src');
      params = $.extend({},extract_params(src),{
        keymeta: JSON.stringify($table.data('keymeta')||{}),
        wire: JSON.stringify(wire_manifest),
        orient: JSON.stringify(manifest_c.manifest),
        more: JSON.stringify(more),
        config: JSON.stringify(config),
        incr_ok: manifest_c.incr_ok,
        series: JSON.stringify(config.columns),
        ssplugins: JSON.stringify(config.ssplugins)
      });
      $.post($table.data('src'),params,function(res) {
        maybe_use_response(widgets,$table,res,config);
      },'json');
    }
  }

  function maybe_get_new_data(widgets,$table,config) {
    var old_manifest = $table.data('manifest') || {};
    var orient = $.extend(true,{},$table.data('view'));
    $table.data('orient',orient);
    var manifest_c = build_manifest(config,orient,old_manifest.manifest);
    $table.data('manifest',manifest_c);
    if($.orient_compares_equal(manifest_c.manifest,old_manifest.manifest)) {
      rerender_grid(widgets,$table,manifest_c);
    } else {
      get_new_data(widgets,$table,manifest_c,null,config);
    }
  }

  var fluxion = {};
  function flux(widgets,$table,type,state) {
    var change = -1;
    if(!fluxion[type]) { fluxion[type] = 0; }
    if(fluxion[type] == 0 && state) { change = 1; }
    fluxion[type] += state;
    if(fluxion[type] == 0 && state) { change = 0; }
    if(change == -1) { return $.Deferred().resolve(); }
    $.each(widgets,function(key,fn) {
      if(fn.flux) { fn.flux($table,type,change); }
    });
    var $d = $.Deferred();
    setTimeout(function() { $d.resolve(); },1);
    return $d;
  }

  function prepopulate_ranges($table,config) {
    var fixed = {};
    $.each(config.colconf,function(key,cc) {
      if(cc.range_range) {
        fixed[key] = cc.range_range;
      }
    });
    $table.data('range-fixed',fixed);
  }

  function markup_activate(widgets,config,$table,$some) {
    $.each(widgets,function(key,fn) {
      if(fn.go_data) { fn.go_data($some); }
    });
  }

  function paint_individual(widgets,$table,key,val) {
    $.each(widgets,function(name,fn) {
      if(fn.paint) { val = fn.paint($table,key,val); }
    });
    return val;
  }

  function new_table($target) {
    var config = $.parseJSON($target.text());
    var widgets = make_widgets(config);
    $.each(config.formats,function(i,fmt) {
      if(!config.orient.format && widgets[fmt]) {
        config.orient.format = fmt;
      }
    });
    var $table = $('<div class="layout"/>');
    $table = build_frame(config,widgets,$table);
    make_chain(widgets,config,$table);
    $table.data('src',$target.attr('href'));
    store_keymeta($table,config.keymeta); 
    $target.replaceWith($table);
    var stored_config = {
      columns: config.columns,
      unique: config.unique
    };
    var view = $.extend(true,{},config.orient);
    var old_view = $.extend(true,{},config.orient);

    prepopulate_ranges($table,config);
    $table.data('view',view).data('old-view',$.extend(true,{},old_view))
      .data('config',stored_config);
    $table.data('payload_one',config.payload_one);
    build_format(widgets,$table);
//    $table.helptip();
    $table.on('view-updated',function() {
      var view = $table.data('view');
      console.log("view updated",view);
      var old_view = $table.data('old-view');
      if(view.format != old_view.format) {
        build_format(widgets,$table);
      }
      flux(widgets,$table,'think',1).then(function() {
        maybe_get_new_data(widgets,$table,config);
        $table.data('old-view',$.extend(true,{},view));
        flux(widgets,$table,'think',-1);
      });
    });
    $table.on('markup-activate',function(e,$some) {
      markup_activate(widgets,config,$table,$some);
    });
    $table.on('spawn',function(e,extra,$frame) {
      var src = $table.data('src');
      var orient = $.extend({},$table.data('view'),extra);
      var params = $.extend({},extract_params(src),{
        keymeta: JSON.stringify($table.data('keymeta')||{}),
        config: JSON.stringify(config),
        orient: JSON.stringify(orient),
        wire: JSON.stringify(orient)
      });
      var out = '<form method="POST" id="spawn" action="'+src+'">';
      $.each(params,function(k,v) {
        var v_esc = $("<div/>").text(v).html().replace(/"/g,"&quot;");
        out += '<input type="hidden" name="'+k+'" value="'+v_esc+'"/>';
      });
      out += "</form><script></script>";
      $frame.contents().find('body').append(out);
      $frame.contents().find('#spawn').submit();
    });
    $table.on('paint-individual',function(e,$el,key,val) {
      $el.html(paint_individual(widgets,$table,key,val));
    });
    $('div[data-widget-name]',$table).each(function(i,el) {
      var $widget = $(el);
      var name = $widget.attr('data-widget-name');
      if($widget.hasClass('_inited')) { return; }
      $widget.addClass('_inited');
      widgets[name].go($table,$widget);
    });
    flux(widgets,$table,'think',1).then(function() {
      maybe_get_new_data(widgets,$table,config);
      flux(widgets,$table,'think',-1);
    });
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

  $.find_type = function(widgets,cc) {
    var w;
    $.each(widgets,function(name,contents) {
      if(contents.types) {
        for(var i=0;i<contents.types.length;i++) {
          if(contents.types[i].name == cc.type_js) {
            w = contents.types[i];
          }
        }
      }
    });
    if(w) { return w; }
    return null;
  };

  $.debounce = function(fn,msec) {
    var id;
    return function () {
      var that = this;
      var args = arguments;
      if(!id) {
        id = setTimeout(function() {
          id = null;
          fn.apply(that,args);
        },msec);
      }
    }
  }

  $.fn.newTable = function() {
    this.each(function(i,outer) {
      new_table($(outer));
    });
    return this;
  }; 

})(jQuery);
