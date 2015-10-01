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
  function beat(def,sleeplen) {
    return def.then(function(data) {
      var d = $.Deferred();
      setTimeout(function() { d.resolve(data); },sleeplen);
      return d;
    });
  }

  function uncompress(raw) {
    var inflate = new Zlib.Inflate(decodeB64(raw));
    var plain = inflate.decompress();
    var out = "";
    // TODO do it faster
    for(var i=0;i<plain.length;i++) {
      out = out + String.fromCharCode(plain[i]);
    }
    return $.parseJSON(out);
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
        widgets[key] = $.fn[name](config,data,widgets);
      }
    });
    return widgets;
  }

  function build_frame(config,widgets,$html) {
    /* Build full list of slots and construct frame */
    var full_frame = {};
    var cwidgets = [];
    var tags = {};
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
        $html = out.$;
      }
    });
    /* Survey for those that need a position */
    var candidates = {};
    $.each(cwidgets,function(j,key) {
      var widget = widgets[key];
      if(widget.position) {
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
        ww[i][2].$.append($widget);
      } 
    });
    return $html;
  }

  function make_chain(widgets,config,$table) {
    config.pipes = [];
    var cwidgets = [];
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

  function build_orient(widgets,$table,manifest_c,data,data_series,destination) {
    var orient = $.extend(true,{},manifest_c.manifest);
    var d = $.Deferred();
    d.resolve([orient,data,0]);
    flux(widgets,$table,'think',1);
    var fn = function(input) {
      var step = manifest_c.undo[input[2]];
      var output = step(input[0],input[1],data_series,destination);
      return [output[0],output[1],input[2]+1];
    };
    for(var i=0;i<manifest_c.undo.length;i++) {
      d = beat(d.then(fn),10);
    }
    d = d.then(function(input) {
      flux(widgets,$table,'think',-1);
      return { orient: input[0], data: input[1] };
    });
    return d;
  }

  function build_enums(manifest_c,grid,series,enums) {
    $.each(manifest_c.eundo,function(i,step) {
      enums = step(enums,grid,series);
    });
    return enums;
  }

  function build_format(widgets,$table) {
    var view = $table.data('view');
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
    var i;
    var fwd = $table.data('grid-series') || [];
    var rev = {};
    for(i=0;i<fwd.length;i++) { rev[fwd[i]] = i; }
    for(i=0;i<series.length;i++) {
      if(rev.hasOwnProperty(series[i])) { continue; }
      rev[series[i]] = fwd.length;
      fwd.push(series[i]);
    }
    $table.data('grid-series',fwd);
    var out = [];
    for(i=0;i<series.length;i++) {
      out.push(rev[series[i]]);
    }
    return out;
  }

  function store_response_in_grid($table,cols,nulls,order,start,manifest_in,series) {
    var grid = $table.data('grid') || [];
    var grid_manifest = $table.data('grid-manifest') || [];
    var indexes = build_series_index($table,series);
    if(!$.orient_compares_equal(manifest_in,grid_manifest)) {
      grid = [];
      $table.data('grid-manifest',manifest_in);
    }
    for(var i=0;i<cols.length;i++) {
      for(var j=0;j<cols[i].length;j++) {
        grid[start+j] = (grid[start+j]||[]);
        if(nulls[i][order[j]]) {
          grid[start+j][indexes[i]] = null;
        } else {
          grid[start+j][indexes[i]] = cols[i][order[j]];
        }
      }
    }
    $table.data('grid',grid);
  }

  function store_ranges($table,enums,cur_manifest,manifest_in,config,widgets) {
    var grid = $table.data('grid') || [];
    var series = $table.data('grid-series') || [];
    enums = build_enums(cur_manifest,grid,series,enums) || {};
    var ranges = $table.data('ranges') || {};
    var range_manifest = $table.data('range-manifest') || [];
    if(!$.orient_compares_equal(manifest_in,range_manifest)) {
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
    build_orient(widgets,$table,manifest_c,grid,grid_series,view).done(function(orient_c) {
      if(manifest_c.all_rows) {
        start = 0;
        length = orient_c.data.length;
      }
      if($.orient_compares_equal(orient_c.orient,view)) {
        widgets[view.format].add_data($table,orient_c.data,grid_series,start,length,orient_c.orient);
        widgets[view.format].truncate_to($table,orient_c.data,grid_series,orient_c.orient);
      }
    });
  }

  function rerender_grid(widgets,$table,manifest_c) {
    render_grid(widgets,$table,manifest_c,0,-1);
  }

  function uncompress_response(response) {
    var i;
    var data = [];
    var nulls = [];
    var totlen = 0;
    for(i=0;i<response.nulls.length;i++) {
      var n = uncompress(response.nulls[i]);
      var d = uncompress(response.data[i]);
      totlen += response.len[i];
      for(var j=0;j<n.length;j++) {
        if(i===0) { data[j] = []; nulls[j] = []; }
        var m = 0;
        var dd = [];
        for(var k=0;k<n[j].length;k++) {
          if(n[j][k]) { dd.push(null); }
          else { dd.push(d[j][m++]); }
        }
        data[j] = data[j].concat(dd);
        nulls[j] = nulls[j].concat(n[j]);
      }
    }
    var order = response.order;
    if(!order) {
      order = [];
      for(i=0;i<totlen;i++) { order[i] = i; }
    }
    return { 'data': data, 'nulls': nulls,
             'order': order, 'totlen': totlen };
  }

  function use_response(widgets,$table,manifest_c,response,config) {
    var data = uncompress_response(response);
    store_response_in_grid($table,data.data,data.nulls,data.order,
                           response.start,manifest_c.manifest,
                           response.series);
    render_grid(widgets,$table,manifest_c,response.start,data.totlen);
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
    if(more===null) { flux(widgets,$table,'load',1); }

    var payload_one = $table.data('payload_one');
    if(payload_one && $.orient_compares_equal(manifest_c.manifest,config.orient)) {
      $table.data('payload_one','');
      maybe_use_response(widgets,$table,payload_one,config);
    } else {
      var wire_manifest = $.extend({},manifest_c.manifest,manifest_c.wire);
      var src = $table.data('src');
      var params = $.extend({},extract_params(src),{
        keymeta: JSON.stringify($table.data('keymeta')||{}),
        wire: JSON.stringify(wire_manifest),
        orient: JSON.stringify(manifest_c.manifest),
        more: JSON.stringify(more),
        config: JSON.stringify(config),
        incr_ok: manifest_c.incr_ok,
        series: JSON.stringify(config.columns),
        ssplugins: JSON.stringify(config.ssplugins),
        source: 'enstab'
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
  var fluxes = {};
  function flux(widgets,$table,type,state,kind) {
    if(kind!==undefined && kind!==null) {
      if(fluxes.hasOwnProperty(kind) && state>0) {
        return;
      }
      fluxes[kind] = 1;
    }
    var change = -1;
    if(!fluxion[type]) { fluxion[type] = 0; }
    if(fluxion[type] === 0 && state) { change = 1; }
    fluxion[type] += state;
    if(fluxion[type] === 0 && state) { change = 0; }
    if(change == -1) { return $.Deferred().resolve(); }
    if(kind!==undefined && kind!==null && change===0) {
      if(fluxes.hasOwnProperty(kind)) { delete fluxes[kind]; }
    }
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

  function markup_activate(widgets,$some) {
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
    $table.on('think-on',function(e,key) { flux(widgets,$table,'think',1,key); });
    $table.on('think-off',function(e,key) { flux(widgets,$table,'think',-1,key); });
    build_format(widgets,$table);
    $table.on('view-updated',function() {
      var view = $table.data('view');
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
      markup_activate(widgets,$some);
    });
    $table.on('spawn',function(e,extra,$frame) {
      var src = $table.data('src');
      var orient = $.extend({},$table.data('view'),extra);
      var spawntoken = Math.floor(Math.random()*1000000000);
      var params = $.extend({},extract_params(src),{
        keymeta: JSON.stringify($table.data('keymeta')||{}),
        config: JSON.stringify(config),
        orient: JSON.stringify(orient),
        wire: JSON.stringify(orient),
        ssplugins: JSON.stringify(config.ssplugins),
        spawntoken: spawntoken,
        source: 'enstab'
      });
      var out = '<form method="POST" id="spawn" action="'+src+'">';
      $.each(params,function(k,v) {
        var v_esc = $("<div/>").text(v).html().replace(/"/g,"&quot;");
        out += '<input type="hidden" name="'+k+'" value="'+v_esc+'"/>';
      });
      out += "</form><script></script>";
      $frame.contents().find('body').empty().append(out);
      $frame.contents().find('#spawn').submit();
      var iter=0;
      var spawn_done_test = function() {
        var parts = document.cookie.split("spawntoken=");
        var value = null;
        if(parts.length==2) { value = parts.pop().split(";").shift(); }
        if(value==spawntoken) {
          flux(widgets,$table,'think',-1,'spawn');
        } else {
          if(iter++<600) { setTimeout(spawn_done_test,1000); }
        }
      };
      flux(widgets,$table,'think',1,'spawn');
      spawn_done_test();
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
    if($table.data('abandon-ship')) { return; }
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
    };
  };

  $.whenquiet = function(fn,msec,$table,key) {
    var id;
    return function() {
      if($table) { $table.trigger('think-on',[key]); }
      var that = this;
      var args = arguments;
      if(id) { clearTimeout(id); }
      id = setTimeout(function() {
        id = null;
        if($table) { $table.trigger('think-off',[key]); }
        fn.apply(that,args);
      },msec);
    };
  };

  $.fn.newTable = function() {
    this.each(function(i,outer) {
      new_table($(outer));
    });
    return this;
  }; 

})(jQuery);
