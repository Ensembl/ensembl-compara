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

  function obj_empty(x) {
    for(var k in x) {
      if(x.hasOwnProperty(k)) { return false; }
    }
    return true;
  }

  $.fn.newtable_filterrange_class = function($el,values,state) {
    var v = {};
    var $out = $("<ul/>");
    values = values.slice();
    values.sort(function(a,b) { return a.localeCompare(b); });
    $.each(values,function(i,val) {
      var $li = $("<li/>").text(val).data('key',val).appendTo($out);
      $li.data('val',val);
      if(!state[val]) { $li.addClass("on"); }
      $li.on('click',function() {
        $(this).toggleClass('on');
        var key = $(this).data('key');
        if(state[val]) { delete state[val]; } else { state[val] = 1; }
        $el.trigger('update',state);
      });
    });
    if(values.length>2) { $out.addClass('use_cols'); }
    return $out;
  };

  $.fn.new_table_filter = function(config,data) {

    var filterable_columns = [];

    function dropdown(idx,key,filter,label) {
      return '<li class="t" data-idx="'+idx+'"><span class="k">'+label+'</span><span class="v">All</span><div class="m" data-filter="'+filter+'">'+label+'</div></li>';
    }

    function menu($table,$button) {
      var idx = $button.data('idx');
      var key = config.columns[idx].key;
      var state = (($table.data('view').filter||{})[key])||{};
      var kind = config.colconf[key].range;
      var values = ($table.data('ranges')||{})[key];
      if(!values) { values = []; }
      return $.fn['newtable_filterrange_'+kind]($button,values,state);
    }

    function update_button($table,$el) {
      var view = $table.data('view');
      if(!view.filter) { view.filter = {}; }
      var idx = $el.data('idx');
      var key = config.columns[idx].key;
      if(view.filter.hasOwnProperty(key)) {
        var values = ($table.data('ranges')||{})[key];
        if(!values) { values = []; }
        var skipping = {};
        $.each(view.filter[key],function(k,v) { skipping[k]=1; });
        var on = [];
        var off = [];
        $.each(values,function(i,v) {
          if(skipping[v]) { off.push(v); } else { on.push(v); }
        });
        var out = "None";
        if(on.length<=off.length) {
          out = on.join(', ');
        } else if(on.length) {
          out = 'All except '+off.join(', ');
        }
        if(out.length>20) {
          out = out.substr(0,20)+'...('+on.length+'/'+values.length+')';
        }
        $('.v',$el).text(out);
      } else {
        $('.v',$el).text('All');
      }
    }

    function update_state($table,$el,state) {
      var view = $table.data('view');
      if(!view.filter) { view.filter = {}; }
      var idx = $el.data('idx');
      var key = config.columns[idx].key;
      if(obj_empty(state)) {
        delete view.filter[key];
      } else {
        view.filter[key] = state;
      }
      if(obj_empty(view.filter)) { delete view.filter; }
      $table.data('view',view);
    }

    return {
      generate: function() {
        var dropdowns = "";
        for(var i=0;i<config.columns.length;i++) {
          var c = config.columns[i];
          if(c.filter) {
            dropdowns += dropdown(i,c.key,c.filter,c.label||c.key);
            filterable_columns.push(c.key);
          }
        }
        var out='<div class="newtable_filter"><ul>'+dropdowns+'</ul></div>';
        return out;
      },
      go: function($table,$el) {
        var trigger_soon = $.debounce(function() {
          $table.trigger('view-updated');
        },10000);
        $('li.t',$el).on('update',function(e,state) {
          update_state($table,$(this),state);
          update_button($table,$(this));
          trigger_soon();
        });
        $table.on('range-updated',function(e) {
          $('li.t',$el).each(function() { update_button($table,$(this)); });
        });
        $('li.t',$el).each(function() { update_button($table,$(this)); });
        $('html').on('click',function(e) {
          var $button = $(e.target).closest('.newtable_filter li.t');
          var $el = $button.find('.m');
          var $menu = $(e.target).closest('.newtable_filter li.t .m');
          $('.newtable_filter li .m:visible').each(function() {
            if($el.length && $el[0] == this) { return; }
            $(this).hide();
          });
          if($button.length && !$menu.length) {
            if(!$el.is(":visible")) {
              $el.empty().append(menu($table,$button));
              $el.show();
              if($el.offset().left+$el.width()>$el.width()) {
                $el.addClass('edge');
              } else {
                $el.removeClass('edge');
              }
            } else {
              $el.hide();
            }
          }
        });
      },
      pipe: function() {
        return [
          function(need,got) {
            need.enumerate = filterable_columns;
          }
        ];
      }
    };
  }; 

})(jQuery);
