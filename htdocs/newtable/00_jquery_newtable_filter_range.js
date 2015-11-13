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
      detect_catastrophe: function($el,$slider,best,km) {
        var minmax = is_minmax($el,$slider,null,null,km);
        if(best.chr != $el.data('slider-chr') &&
          (!minmax.min || !minmax.max)) {
          $el.data('slider-chr',best.chr);
          return true;
        } else {
          return false;
        }
      },
      text_prefix: function(state) { return state.chr+':'; },
      draw_additional: function($el,values) {
        $el.data('slider-chr',values.chr);
      }
    },
    range: {
      summary_prefix: function($button) { return ''; },
      additional_update: function(update,$button) {},
      preproc_values: function(values) { return values; },
      detect_catastrophe: function($el,$slider,values,km) { return false; },
      text_prefix: function(state) { return ''; },
      draw_additional: function($el,values) {}
    }
  };

  function is_minmax($el,$slider,min,max,km) {
    if(km && km['*'] && km['*'].fixed) { return { min: 0, max: 0 }; }
    var range = $el.data('slider-range');
    if($slider) {
      if(min===null) { min = $slider.slider('option','values.0'); }
      if(max===null) { max = $slider.slider('option','values.1'); }
    }
    var is_min = (min===null || 1*min < 1*range[0]);
    var is_max = (max===null || 1*max > 1*range[1]);
    return { min: is_min, max: is_max };
  }

  function update_widget(variety,$button,$el,min,max,km,values,no_slide) {
    var fixed = (km && km['*'] && km['*'].fixed);
    var $slider = $('.slider',$el);
    if(fixed) {
      if(min===null || min===undefined) { min = values.min; }
      if(max===null || max===undefined) { max = values.max; }
    } else {
      var full_range = $slider.slider('option','values');
      if(min===null || min===undefined) { min = full_range[0]; }
      if(max===null || max===undefined) { max = full_range[1]; }
    }
    var $feedback = $('.slider_feedback',$el);
    var prefix = variety.summary_prefix($button);
    var minmax = is_minmax($button,null,min,max,km);
    /* Update text */
    $feedback.text(prefix+(minmax.min?"Min":min)+" - "+
                   prefix+(minmax.max?"Max":max));
    /* Update slider */
    if(!no_slide) {
      // no_slide set when in callback for slide to avoid loop!
      $slider.slider('option','values',[parseFloat(min),parseFloat(max)]);
    }
    /* Update tickbox */
    var $tickbox = $('.slider_unspecified input',$el);
    if($tickbox.length) {
      if(!$button.data('unspec-explicit')) {
        if(minmax.min && minmax.max) {
          $tickbox.prop('checked',true);
        } else {
          $tickbox.prop('checked',false);
        }
      }
    }
  }

  function force_blanks($el,val) {
    $('.slider_unspecified input',$el).prop('checked',val);
  }

  function calc_step(km,min,max) {
    min = parseFloat(min);
    max = parseFloat(max);
    var step = (max-min)/200;
    if(step === 0) { step = 1; }
    if(km && km['*'] && km['*'].integer) { step = 1; }
    return step;
  }

  function send_update(variety,$button,km) {
    var fixed = (km && km['*'] && km['*'].fixed);
    var $slider = $('.slider',$button);
    var pmin = $slider.slider('option','values.0');
    var pmax = $slider.slider('option','values.1');
    var minmax = is_minmax($button,null,pmin,pmax,km);
    var $tickbox = $('.slider_unspecified input',$button);
    var fixed = (km && km['*'] && km['*'].fixed);
    var update = {};
    if($tickbox.length) {
      update.no_nulls = !$tickbox.prop('checked');
    } else if(fixed) {
      var range = $button.data('slider-range');
      update.no_nulls = !( range[0] == pmin && range[1] == pmax );
    } else {
      update.no_nulls = !(minmax.min && minmax.max);
    }
    variety.additional_update(update,$button);
    if(!minmax.min) { update.min = pmin; }
    if(!minmax.max) { update.max = pmax; }
    if(fixed) {
      var range = $button.data('slider-range');
      if(update.min == range[0]) { delete update.min; }
      if(update.max == range[1]) { delete update.max; }
    }
    if(!update.no_nulls) { delete update.no_nulls; }
    $button.trigger('update',update);
  }

  function draw_slider(variety,$out,$button,min,max,km,values) {
    min = 1*min;
    max = 1*max;
    var step = calc_step(km,min,max);
    $button.data('slider-range',[min,max]);
    var fixed = (km && km['*'] && km['*'].fixed);
    return $('<div/>').addClass('slider').appendTo($out).slider({
      range: true,
      min: fixed?min:min-step, max: fixed?max:max+step, step: step,
      values: [fixed?min:min-step,fixed?max:max+step],
      slide: function(e,ui) {
        update_widget(variety,$button,$out,ui.values[0],ui.values[1],km,values,true);
      },
      stop: function(e,ui) {
        send_update(variety,$button,km);
      }
    });
  }

  function draw_widget(variety,$button,min,max,km,values) {
    var fixed = (km && km['*'] && km['*'].fixed);
    var $out = $("<div/>").addClass('newtable_range');
    $('<div/>').addClass('slider_feedback').appendTo($out);
    draw_slider(variety,$out,$button,min,max,km,values);
    if(km && km['*'] && km['*'].blank_button) {
      var $unspec = $('<div/>').addClass('slider_unspecified');
      $unspec.append("<span>include blank</span>");
      var $tickbox = $('<input type="checkbox"/>').appendTo($unspec);
      $unspec.appendTo($out);
      $tickbox.on('click',function() {
        $button.data('unspec-explicit',true);
        send_update(variety,$button,km);
      }).prop('checked',true);
    }
    update_widget(variety,$button,$out,null,null,km,values,true);
    return $out;
  }

  function slider_update_size($el,$slider,min,max,km) {
    var fixed = (km && km['*'] && km['*'].fixed);
    var step = calc_step(km,min,max);
    $slider.slider('option','min',parseFloat(min)-(fixed?0:step));
    $slider.slider('option','max',parseFloat(max)+(fixed?0:step));
    $el.data('slider-range',[min,max]);
  }

  function slider_set_minmax($slider,pos) {
    var val = $slider.slider('option',pos?'max':'min');
    $slider.slider('values',pos,val);
  }

  $.fn.newtable_filter_range = function(config,data) {
    var filters = [];
    $.each(varieties,function(name,variety) {
      filters.push({
        name: name,
        display: function($menu,$el,values,state,km) {
          values = variety.preproc_values(values);
          var $slider = $('.slider',$menu);
          if($slider.length) {
            var minmax = is_minmax($el,$slider,null,null,km);
            if(variety.detect_catastrophe($el,$slider,values,km)) {
              slider_update_size($el,$slider,values.min,values.max,km);
              slider_set_minmax($slider,0);
              slider_set_minmax($slider,1);
              update_widget(variety,$el,$menu,state.min,state.max,km,values);
              force_blanks($menu,true);
              send_update(variety,$el,km);
            } else {
              slider_update_size($el,$slider,values.min,values.max,km);
              if(minmax.min) { slider_set_minmax($slider,0); }
              if(minmax.max) { slider_set_minmax($slider,1); }
              update_widget(variety,$el,$menu,state.min,state.max,km,values);
            }
          } else {
            var $out = draw_widget(variety,$el,values.min,values.max,km,values);
            variety.draw_additional($el,values);
            $menu.empty().append($out);
            update_widget(variety,$el,$menu,state.min,state.max,km,values);
          }
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
        },
      });
    });
    return { filters: filters }; 
  };
})(jQuery);
