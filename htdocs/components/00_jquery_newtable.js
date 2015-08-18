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
      if(!compares_equal(fb[idx],val)) { good = false; }
    });
    $.each(fb,function(idx,val) {
      if(!compares_equal(fa[idx],val)) { good = false; }
    });
    return good;
  }

  function use_response(widgets,$table,data,orientation) {
    var view = $table.data('view');
    widgets[view.format].add_data($table,data.data,data.start,data.columns,orientation);
  }
  
  function maybe_use_response(widgets,$table,result) {
    var cur_data = $table.data('data');
    var in_data = result.data;
    if(compares_equal(cur_data,in_data)) {
      use_response(widgets,$table,result.response,result.data);
      if(result.response.more) {
        console.log("continue");
        get_new_data(widgets,$table,in_data,result.response.more);
      }
    }
  }

  function get_new_data(widgets,$table,data,more) {
    console.log("data changed, should issue request");
    $.get($table.data('src'),{
      data: JSON.stringify(data),
      more: JSON.stringify(more),
      config: JSON.stringify($table.data('config'))
    },function(res) {
      maybe_use_response(widgets,$table,res);
    },'json');
  }

  function maybe_get_new_data(widgets,$table) {
    var old_data = $table.data('old-data');
    var view = $table.data('view');
    var data = $.extend(true,{},view);
    delete data.format;
    $table.data('data',data);
    console.log("old-data",JSON.stringify(old_data));
    console.log("data",JSON.stringify(data));
    if(!compares_equal(data,old_data)) {
      get_new_data(widgets,$table,data,null);
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
    var $table = $('<div class="new_table_wrapper '+config.cssclass+'"><div class="topper"></div><div class="layout"></div></div>');
    $('.topper',$table).html(new_top(widgets,config));
    var stored_config = {
      columns: config.columns,
      unique: config.unique,
      type: config.type
    };
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
