/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

  function make_widgets(config,call_widgets) {
    var widgets = {};
    $.each(config.widgets,function(key,name) {
      var data = {};
      if($.isArray(name)) {
        data = name[1];
        name = name[0];
      }
      if($.isFunction($.fn[name])) {
        widgets[key] = $.fn[name](config,data,widgets,call_widgets);
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
    var drevpipe = [];
    var wire = {};
    var manifest = $.extend(true,{},orient);
    $.each(config.pipes,function(i,step) {
      var out = step(manifest,target,wire);
      if(out) {
        if(out.manifest) { manifest = out.manifest; }
        if(out.undo) { revpipe.push(out.undo); }
        if(out.dundo) { drevpipe.push(out.dundo); }
        if(out.eundo) { erevpipe.push(out.eundo); }
        if(out.no_incr) { incr = false; }
        if(out.all_rows) { all_rows = true; }
      }
    });
    return { manifest: manifest, undo: revpipe, eundo: erevpipe, wire: wire,
             incr_ok: incr, all_rows: all_rows, dundo: drevpipe };
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

  function build_enums(manifest_c,grid,series,enums,keymeta) {
    $.each(manifest_c.eundo,function(i,step) {
      enums = step(enums,grid,series,keymeta);
    });
    return enums;
  }

  function build_format(widgets,$table) {
    var view = $table.data('view');
    $('.layout',$table).html(
      '<div data-widget-name="'+view.format+'">'+
      widgets[view.format].layout($table,widgets)+"</div>"
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
    var i,j;
    var grid = $table.data('grid') || [];
    var grid_manifest = $table.data('grid-manifest') || [];
    var indexes = build_series_index($table,series);
    if(!$.orient_compares_equal(manifest_in,grid_manifest)) {
      grid = [];
      $table.data('grid-manifest',manifest_in);
    }
    for(i=0;i<cols.length;i++) {
      var pos = order;
      var pos_max = 0;
      if(!pos) {
        pos = [];
        for(j=0;j<cols[i].length;j++) { pos[start+j] = start+j; }
      }
      for(j=0;j<pos.length;j++) {
        if(pos[j] && pos[j]>pos_max) { pos_max=pos[j]; }
      }
      for(j=0;j<=pos_max;j++) {
        if(!grid[j]) { grid[j] = []; }
      }
      for(j=0;j<cols[i].length;j++) {
        var val = null;
        if(!nulls[i][j]) { val = cols[i][j]; }
        grid[pos[j+start]][indexes[i]] = val;
      }
    }
    $table.data('grid',grid);
  }

  function store_ranges($table,enums,cur_manifest,manifest_in,config,widgets) {
    var grid = $table.data('grid') || [];
    var series = $table.data('grid-series') || [];
    var keymeta = $table.data('keymeta')||{};
    enums = build_enums(cur_manifest,grid,series,enums,keymeta) || {};
    var ranges = $table.data('ranges') || {};
    var range_manifest = $table.data('range-manifest') || [];
    if(!$.orient_compares_equal(manifest_in,range_manifest)) {
      ranges = {};
      $table.data('range-manifest',manifest_in);
    }
    $.each(enums,function(column,range) {
      var fn = $.find_type(widgets,config.colconf[column]).merge;
      ranges[column] = fn(ranges[column],range);
    });
    $table.data('ranges',ranges);
    $table.trigger('range-updated');
  }

  function store_keymeta($table,incoming) {
    var keymeta = $table.data('keymeta') || {};
    $.each(incoming||{},function(klass,klassdata) {
      if(!keymeta[klass]) { keymeta[klass] = {}; }
      $.each(klassdata||{},function(col,coldata) {
        if(!keymeta[klass][col]) { keymeta[klass][col] = {}; }
        $.each(coldata||{},function(val,valdata) {
          if(!keymeta[klass][col][val]) { keymeta[klass][col][val] = {}; }
          $.each(valdata||{},function(k,v) {
            keymeta[klass][col][val][k] = v;
          });
        });
      });
    });
    $table.data('keymeta',keymeta);
  }

  function decorate(widgets,$table,grid,manifest_c,orient,series,start,length) {
    var d = $.Deferred();
    d.resolve([0,grid]);
    flux(widgets,$table,'think',1);
    var fn = function(input) {
      var step = manifest_c.dundo[input[0]];
      var data = step(orient,grid,series,start,length);
      return [input[0]+1,data];
    };
    for(var i=0;i<manifest_c.dundo.length;i++) {
      d = beat(d.then(fn),10);
    }
    return d.then(function(x) {
      flux(widgets,$table,'think',-1);
      return x[1];
    });
  }

  function render_grid(widgets,$table,manifest_c,start,length) {
    console.log("render_grid",start,length);
    var view = $table.data('view');
    var grid = $table.data('grid');
    var grid_series = $table.data('grid-series');
    if(length==-1) { length = grid.length; }
    return build_orient(widgets,$table,manifest_c,grid,grid_series,view).then(function(orient_c) {
      if(manifest_c.all_rows) {
        start = 0;
        length = orient_c.data.length;
      }
      if($.orient_compares_equal(orient_c.orient,view)) {
        decorate(widgets,$table,orient_c.data,manifest_c,orient_c.orient,grid_series,start,length).then(function(decorated) {
          widgets[view.format].add_data($table,decorated,grid_series,start,length,orient_c.orient);
          widgets[view.format].truncate_to($table,decorated,grid_series,orient_c.orient);
        });
      }
    });
  }
 
  var pr_start = 0;
  var pr_length = 0;
  var pr_manifest = null;
  var pr_after = null;

  function clear_render_grid() { pr_manifest = null; }

  function run_render_grid(widgets,$table) {
    if(pr_manifest===null) { return; }
    render_grid(widgets,$table,pr_manifest,pr_start,pr_length).then(function() {
    if(pr_after!==null) { pr_after.resolve(); }
    pr_after = null;
    pr_manifest = null;
  });
  }
 
  function maybe_render_grid(widgets,$table,manifest_c,start,length) {
    if(pr_manifest===null) { pr_manifest = manifest_c; }
    if(!$.orient_compares_equal(pr_manifest,manifest_c)) {
      if(pr_after!==null) { pr_after.resolve(); pr_after = null; }
      pr_start = start;
      pr_length = length;
      pr_manifest = manifest_c;
    }
    if(pr_after===null) { pr_after = $.Deferred(); }
    if(start<pr_start) {
      if(pr_length>-1) { pr_length += pr_start-start; }
      pr_start = start;
    }
    if(pr_length==-1 || length==-1) {
      pr_length = -1;
    } else if(start+length>pr_start+pr_length) {
      pr_length = start+length-pr_start;
    }
    if(manifest_c.incr_ok || $table.data('complete')) {
      run_render_grid(widgets,$table);
    }
    return pr_after;
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
    return { 'data': data, 'nulls': nulls, 'totlen': totlen };
  }

  function use_response(widgets,$table,response,phase,config,order) {
    store_keymeta($table,response.keymeta);
    var cur_manifest = $table.data('manifest');
    var data = uncompress_response(phase);
    store_response_in_grid($table,data.data,data.nulls,order,
                           phase.start,cur_manifest.manifest,
                           phase.series);
    store_ranges($table,response.enums||{},cur_manifest,response.shadow,config,widgets);
    var size = $table.data('min-size')||0;
    if(size<phase.shadow_num) { size = phase.shadow_num; }
    $table.data('min-size',size);
    $.each(widgets,function(name,w) {
      if(w.size) { w.size($table,size); }
    });
    return [phase.start,data.totlen];
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

  function maybe_use_responses(widgets,$table,got,config) {
    if(!$table.closest('html').length) { return; }
    var cur_manifest = $table.data('manifest');
    if(got.more) {
      get_new_data(widgets,$table,cur_manifest,got.more,config);
    }
    if($.orient_compares_equal(cur_manifest.manifest,got.orient)) {
      flux(widgets,$table,'think',1);
      var d = $.Deferred().resolve([0,-1,-1]);
      if(!got.more) {
        console.log("complete");
        $table.data('complete',true);
        run_render_grid(widgets,$table);
      }
      var fn = function(x) {
        var start = new Date().getTime();
        var loc = use_response(widgets,$table,got,got.responses[x[0]],config,got.order);
        if(x[1]==-1 || loc[0]<x[1]) { x[1] = loc[0]; }
        if(x[2]==-1 || loc[0]+loc[1]>x[2]) { x[2] = loc[0]+loc[1]; }
        var e = $.Deferred().resolve([x[0]+1,x[1],x[2]]);
        var took = (new Date().getTime())-start;
        if(took<25) { return e; } else { return beat(e,10); }
      };
      for(var i=0;i<got.responses.length;i++) {
        d = d.then(fn);
      }
      d = d.then(function(x) {
        return maybe_render_grid(widgets,$table,cur_manifest,x[1],x[2]-x[1]);
      }).then(function() {
        if(!got.more) { flux(widgets,$table,'load',-1); }
        flux(widgets,$table,'think',-1);
      });
    }
  }

  var o_num = 0;
  var outstanding = [];
  var o_manifest = {};

  function get_new_data(widgets,$table,manifest_c,more,config) {
    if(more===null) { flux(widgets,$table,'load',1); }
    $table.data('complete',false);
    console.log("incomplete");

    // Cancel any ongoing fruitless requests
    if(!$.orient_compares_equal(manifest_c.manifest,o_manifest)) {
      console.log("Cancelling outstanding");
      for(var i=0;i<outstanding.length;i++) {
        if(outstanding[i]) { outstanding[i].abort(); }
        outstanding[i] = null;
      }
      o_num = 0;
      o_manifest = manifest_c.manifest;
    }
    if(!o_num) { outstanding = []; }

    var payload_one = $table.data('payload_one');
    store_keymeta($table,payload_one.keymeta);
    if(payload_one && $.orient_compares_equal(manifest_c.manifest,config.orient)) {
      $table.data('payload_one','');
      maybe_use_responses(widgets,$table,payload_one,config);
    } else {
      if(more===null) { flux(widgets,$table,'think',1); }
      var wire_manifest = $.extend({},manifest_c.manifest,manifest_c.wire);
      var src = $table.data('src');
      var params = $.extend({},extract_params(src),{
        keymeta: JSON.stringify($table.data('keymeta')||{}),
        wire: JSON.stringify(wire_manifest),
        orient: JSON.stringify(manifest_c.manifest),
        more: JSON.stringify(more),
        config: JSON.stringify(config),
        series: JSON.stringify(config.columns),
        ssplugins: JSON.stringify(config.ssplugins),
        source: 'enstab'
      });
      var o_idx = outstanding.length;
      o_num++;
      outstanding[o_idx] = $.post($table.data('src'),params,function(res) {
        outstanding[o_idx] = null;
        o_num--;
        if(more===null) { flux(widgets,$table,'think',-1); }
        maybe_use_responses(widgets,$table,res,config);
      },'json');
    }
  }

  function maybe_get_new_data(widgets,$table,config) {
    var old_manifest = $table.data('manifest') || {};
    var orient = $.extend(true,{},$table.data('view'));
    $table.data('orient',orient);
    var manifest_c = build_manifest(config,orient,old_manifest.manifest);
    $table.data('manifest',manifest_c); 
    clear_render_grid();
    if($.orient_compares_equal(manifest_c.manifest,old_manifest.manifest)) {
      maybe_render_grid(widgets,$table,manifest_c,0,-1);
    } else {
      console.log("crusty data");
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
    if(fluxion[type]<0) { fluxion[type]=0; }
    if(fluxion[type] === 0 && state) { change = 0; }
    if(change == -1) { return $.Deferred().resolve(); }
    if(kind!==undefined && kind!==null && change===0) {
      if(fluxes.hasOwnProperty(kind)) { delete fluxes[kind]; }
    }
    $.each(widgets,function(key,fn) {
      if(fn.flux) {
        // TODO change calls to triggers everywhere
        fn.flux($table,type,change);
        $table.trigger('flux-'+type,[change?true:false]);
      }
    });
    var $d = $.Deferred();
    setTimeout(function() { $d.resolve(); },1);
    return $d;
  }

  function flux_update($table,type) {
    $table.trigger('flux-'+type,[fluxion[type]?true:false]);
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

  var seq = +Date.now();
  function save_orient($table,config,view) {
    seq++;
    var src = $table.data('src');
    var params = $.extend({},extract_params(src),{
      activity: 'save_orient',
      source: 'enstab',
      keymeta: JSON.stringify($table.data('keymeta')||{}),
      config: JSON.stringify(config),
      ssplugins: JSON.stringify(config.ssplugins),
      orient: JSON.stringify(view),
      seq: seq
    });
    $.post($table.data('src'),params,function(res) {},'json');
  }

  function load_orient($table,config) {
    var src = $table.data('src');
    var params = $.extend({},extract_params(src),{
      activity: 'load_orient',
      source: 'enstab',
      keymeta: JSON.stringify($table.data('keymeta')||{}),
      config: JSON.stringify(config),
      ssplugins: JSON.stringify(config.ssplugins)
    });
    $.post(src,params,function(res) {
      $table.data('view',res.orient);
      $table.trigger('view-updated');
    },'json');
  }

  function new_table($target) {
    var config = $.parseJSON($target.text());
    var cwidgets = [];
    var widgets = [];
    var call_widgets = function(method) {
      var args = (arguments.length === 1 ? [arguments[0]] : Array.apply(null, arguments)); // copy args to avoid V8 performance penalty
      var method = args[0];
      var ret = { _all: true, _any: false, _last: undefined };
      args = args.slice(1);
      $.each(cwidgets,function(i,key) {
        var widget = widgets[key];
        if(widget[method]) {
          args.push(ret._last);
          ret[key] = widget[method].apply(this,args);
          args.pop();
          ret._all = ret._all && ret[key];
          ret._any = ret._any || ret[key];
          ret._last = ret[key];
        }
      });
      return ret;
    };
    widgets = make_widgets(config,call_widgets);
    $.each(widgets,function(key,widget) { cwidgets.push(key); });
    cwidgets.sort(function(a,b) { return (widgets[a].prio||50)-(widgets[b].prio||50); });
    var $table = $('<div class="layout"/>');
    $table = build_frame(config,widgets,$table);
    make_chain(widgets,config,$table);
    $table.data('src',$target.attr('href'));
    $target.replaceWith($table);
    var stored_config = {
      columns: config.columns
    };
    var view = $.extend(true,{},config.orient);
    $table.data('view',view).data('old-view',{})
      .data('config',stored_config);
    $table.data('payload_one',config.payload_one);
    delete config.payload_one;
    $table.on('think-on',function(e,key) { flux(widgets,$table,'think',1,key); });
    $table.on('think-off',function(e,key) { flux(widgets,$table,'think',-1,key); });
    $table.on('flux-update',function(e,type) { flux_update($table,type); });
    build_format(widgets,$table);
    $table.on('view-updated',function() {
      var view = $table.data('view');
      save_orient($table,config,view);
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
        more: JSON.stringify(null),
        source: 'enstab',
        incr_ok: 0
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
    load_orient($table,config);
  }

  // TODO make this configurable ENSWEB-2113
  function merge_orient(lesser,greater) {
    return $.extend({},lesser,greater);
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
