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

  $.fn.new_table_filter = function(config,data,widgets) {

    var filterable_columns = [];

    function find_widget(filter_name) {
      var w;
      $.each(widgets,function(name,contents) {
        if(contents.filters) {
          for(var i=0;i<contents.filters.length;i++) {
            if(contents.filters[i].name == filter_name) {
              w = contents.filters[i];
            }
          }
        }
      });
      if(w) { return w; }
      if(filter_name != 'class') { return find_widget('class'); }
      return null;
    }

    function dropdown(idx,key,filter,label) {
      return '<li class="t" data-idx="'+idx+'"><span class="k">'+label+'</span><span class="v">All</span><div class="m" data-filter="'+filter+'">'+label+'</div></li>';
    }

    function menu($table,$button,$menu) {
      var idx = $button.data('idx');
      var key = config.columns[idx].key;
      var state = (($table.data('view').filter||{})[key])||{};
      var kind = config.colconf[key].range;
      var values = ($table.data('ranges')||{})[key];
      if(!values) { values = []; }
      var kparams = config.colconf[key].range_params;
      var w = find_widget(kind);
      w.display($menu,$button,values,state,kparams);
    }

    function update_button($table,$el) {
      var view = $table.data('view');
      if(!view.filter) { view.filter = {}; }
      var idx = $el.data('idx');
      var key = config.columns[idx].key;
      var values = ($table.data('ranges')||{})[key];
      var kind = config.colconf[key].range;
      var w = find_widget(kind);
      $el.toggleClass('valid',!!w.visible(values));
      var $filters = $('.newtable_filter',$table);
      var $vbuts = $('.t.valid',$filters);
      $filters.toggle(!!$vbuts.length);
      if(view.filter.hasOwnProperty(key)) {
        var w = find_widget(kind);
        var text = w.text(view.filter[key],values);
        $('.v',$el).text(text);
      } else {
        $('.v',$el).text('All');
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
      var key = config.columns[idx].key;
      if(obj_empty(state)) {
        delete view.filter[key];
      } else {
        view.filter[key] = state;
      }
      if(obj_empty(view.filter)) { delete view.filter; }
      $table.data('view',view);
    }

    function show_menu($el) {
      $el.removeClass('edge');
      $el.show();
      if($el.offset().left+$el.width()>$('html').width()) {
        $el.addClass('edge');
      }
    }

    function hide_menu($el) {
      $el.hide();
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
        },5000);
        $('li.t',$el).on('update',function(e,state) {
          update_state($table,$(this),state);
          update_button($table,$(this));
          trigger_soon();
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
        $('li.t',$el).each(function() { update_button($table,$(this)); });
        $('html').on('click',function(e) {
          var $button = $(e.target).closest('.newtable_filter li.t');
          var $el = $button.find('.m');
          var $menu = $(e.target).closest('.newtable_filter li.t .m');
          $('.newtable_filter li .m:visible').each(function() {
            if($el.length && $el[0] == this) { return; }
            hide_menu($(this));
          });
          if($button.length && !$menu.length) {
            if(!$el.is(":visible")) {
              menu($table,$button,$el);
              show_menu($el);
            } else {
              hide_menu($el);
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
