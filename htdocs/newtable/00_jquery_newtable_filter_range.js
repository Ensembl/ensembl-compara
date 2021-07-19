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

/* We maintain an internal hash, /position/, reflecting the state of this
 * widget. This updates even during slide, etc, and everything else reads
 * off that to update themselves. This allows the tickbox, etc, to update
 * as we slide along. There's then an explicit call to send this to the
 * filter code.
 */

(function($) {
  var varieties = {
    position: {
      summary_prefix: function($button) {
        return $button.data('slider-chr')+':';
      },
      additional_update: function(update,$button) {
        update.chr = $button.data('slider-chr');
      },
      preproc_values: function(values) {
        var best = null;
        $.each(values,function(name,value) {
          if(value.best) { best = value; }
        });
        return best;
      },
      text_prefix: function(state) { return state.chr+':'; },
      draw_additional: function($el,values) {
        $el.data('slider-chr',values.chr);
      },
      round_out: function(val) { return val; }
    },
    range: {
      summary_prefix: function($button) { return ''; },
      additional_update: function(update,$button) {},
      preproc_values: function(values) { return values; },
      text_prefix: function(state) { return ''; },
      draw_additional: function($el,values) {},
      round_out: function(val) { return round_2sf(val); }
    }
  };

  function round_2sf(val) {
    if($.isNumeric(val)) {
      return parseFloat(val.toPrecision(2));
    } else {
      return val;
    }
  }

  function reset_position($el) {
    $el.data('position',{
      min: null, max: null, nulls: true,
      imp_nulls: true, exp_nulls: null
    });
  }

  function update_position_from_state($el,state) {
    var min = state.min;
    var max = state.max;
    var $slider = $('.slider',$el);
    var fixed = $slider.rangeslider('options').fixed;
    var limits = $slider.rangeslider('get_limits');
    if(min===undefined) { min = fixed?limits[0]:null; }
    if(max===undefined) { max = fixed?limits[1]:null; }
    var pos = $el.data('position');
    pos.min = min;
    pos.max = max;
  }

  function update_slider_from_position($el) {
    var $slider = $('.slider',$el);
    var pos = $el.data('position');
    $slider.rangeslider('set',pos.min,pos.max);
  }
  
  function update_position_from_sliding($el,min,max,in_progress) {
    var $slider = $('.slider',$el);
    var current = $slider.rangeslider('get');
    var pos = $el.data('position');
    pos.min = min;
    pos.max = max;
    if(!in_progress) {
      var $slider = $('.slider',$el);
      var fixed = $slider.rangeslider('options').fixed;
      var limits = $slider.rangeslider('get_limits');
      pos.imp_nulls = false;
      if(fixed && min==limits[0] && max==limits[1]) {
        pos.imp_nulls = true;
      }
      if(!fixed && min===null && max===null) {
        pos.imp_nulls = true;
      }
    }  
  }

  function update_text_from_position($el,variety) {
    var pos = $el.data('position');
    var is_min = (pos.min===null);
    var is_max = (pos.max===null);
    var $feedback = $('.slider_feedback',$el);
    var prefix = variety.summary_prefix($el);
    $feedback.text(prefix+(is_min?"Min":variety.round_out(pos.min))+" - "+
                   prefix+(is_max?"Max":variety.round_out(pos.max)));
  }
   
  function update_tickbox_from_position($el) {
    var $tickbox = $('.slider_unspecified input',$el);
    var pos = $el.data('position');
    var nulls = pos.exp_nulls;
    if(nulls==null) { nulls = pos.imp_nulls; }
    if($tickbox.length) {
      if(nulls) {
        $tickbox.prop('checked',true);
      } else {
        $tickbox.prop('checked',false);
      }
    }
  }

  function update_position_from_tickbox($el) {
    var $tickbox = $('.slider_unspecified input',$el);
    var pos = $el.data('position');
    pos.exp_nulls = $tickbox.prop('checked');
  }

  function update_all_from_position($el,variety) {
    update_slider_from_position($el);
    update_text_from_position($el,variety);
    update_tickbox_from_position($el);
  }

  function send_position(variety,$el) {
    var pos = $el.data('position');
    var update = {};
    if(pos.exp_nulls!==undefined && pos.exp_nulls!==null) {
      update.no_nulls = !pos.exp_nulls;
    } else {
      update.no_nulls = !pos.imp_nulls;
    }
    variety.additional_update(update,$el);
    /* Fixed at endpoint means unrestricted at that end */
    var $slider = $('.slider',$el);
    if($slider.rangeslider('options').fixed) {
      var range = $slider.rangeslider('get_limits');
      if(update.min == range[0]) { update.min = null; }
      if(update.max == range[1]) { update.max = null; }
    }
    update.min = variety.round_out(pos.min);
    update.max = variety.round_out(pos.max);
    /* Tidy so that unrestricted is empty */
    if(!update.no_nulls) { delete update.no_nulls; }
    if(update.min===null) { delete update.min; }
    if(update.max===null) { delete update.max; }
    /* Send */
    $el.trigger('update',update);
  }

  function draw_slider(variety,$out,$button,min,max,km,values) {
    min = 1*min;
    max = 1*max;
    return $('<div/>').appendTo($out).rangeslider({
      min: min, max: max,
      fixed: (km && km['*'] && km['*'].fixed),
      integer: (km && km['*'] && km['*'].integer),
      soggy: (km && km['*'] && km['*'].logarithmic),
      slide: function(min,max) {
        update_position_from_sliding($button,min,max,true);
        update_text_from_position($button,variety);
        update_tickbox_from_position($button);
      },
      stop: function(min,max) {
        update_position_from_sliding($button,min,max,false);
        update_text_from_position($button,variety);
        update_tickbox_from_position($button);
        send_position(variety,$button);
      }
    });
  }

  function draw_widget(variety,$button,min,max,km,values) {
    var fixed = (km && km['*'] && km['*'].fixed);
    var $out = $("<div/>").addClass('newtable_range');
    $('<div/>').addClass('slider_feedback').appendTo($out);
    var $main = $('<div/>').addClass('slider_main').appendTo($out);
    if(km && km['*']) {
      var end_left = km['*'].endpoint_left;
      var end_right = km['*'].endpoint_right;
      if(km['*'].slider_class) {
        $main.addClass(km['*'].slider_class);
      }
    }
    if(!end_left) { end_left = ''; }
    if(!end_right) { end_right = ''; }
    if(end_left) {
      $('<div/>').addClass('slider_left').html(end_left).appendTo($main);
    }
    draw_slider(variety,$main,$button,min,max,km,values);
    if(end_right) {
      $('<div/>').addClass('slider_right').html(end_right).appendTo($main);
    }
    if(km && km['*'] && km['*'].blank_button) {
      var $unspec = $('<div/>').addClass('slider_unspecified');
      $unspec.append("<span>include blank</span>");
      var $tickbox = $('<input type="checkbox"/>').appendTo($unspec);
      $unspec.appendTo($out);
      $tickbox.on('click',function() {
        update_position_from_tickbox($button);
        send_position(variety,$button);
      }).prop('checked',true);
    }
    return $out;
  }

  $.fn.newtable_filter_range = function(config,data) {
    var filters = [];
    $.each(varieties,function(name,variety) {
      filters.push({
        name: name,
        display: function($box,$el,values,state,km) {
          values = variety.preproc_values(values);
          var $slider = $('.slider',$box);
          var $out = draw_widget(variety,$el,values.min,values.max,km,values);
          reset_position($el);
          variety.draw_additional($el,values);
          $box.append($out);
          var $slider = $('.slider',$out); 
          update_position_from_state($el,state);
          update_all_from_position($el,variety);
        },
        text: function(state,all,km) {
          var fixed = (km && km['*'] && km['*'].fixed);
          var has_min = state.hasOwnProperty('min');
          var has_max = state.hasOwnProperty('max');
          var out;
          if((!has_min && !has_max) || 
             (fixed && state.min == all.min && state.max == all.max)) {
            if(state.no_nulls) { return "All except blank"; }
            else { return "All"; }
          } else {
            out = variety.text_prefix(state)+(has_min?state.min:"Min") +
                  " - " +
                  variety.text_prefix(state)+(has_max?state.max:"Max");
            if(!state.no_nulls) { out += " or blank"; }
            return out;
          }
        },
        visible: function(values) {
          if(!values) { return false; }
          values = variety.preproc_values(values);
          return values && values.hasOwnProperty('min');
        }
      });
    });
    return { filters: filters }; 
  };
})(jQuery);
