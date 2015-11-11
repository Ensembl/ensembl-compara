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
      detect_catastrophe: function($el,$slider,best) {
        var minmax = is_minmax($el,$slider,null,null);
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
      detect_catastrophe: function($el,$slider,values) { return false; },
      text_prefix: function(state) { return ''; },
      draw_additional: function($el,values) {}
    }
  };

  function is_minmax($el,$slider,min,max) {
    var range = $el.data('slider-range');
    if($slider) {
      if(min===null) { min = $slider.slider('option','values.0'); }
      if(max===null) { max = $slider.slider('option','values.1'); }
    }
    var is_min = (min===null || 1*min < 1*range[0]);
    var is_max = (max===null || 1*max > 1*range[1]);
    return { min: is_min, max: is_max };
  }

  function update_widget(variety,$button,$el,min,max) {
    var $feedback = $('.slider_feedback',$el);
    var $tickbox = $('.slider_unspecified input',$el);
    var prefix = variety.summary_prefix($button);
    var minmax = is_minmax($button,null,min,max);
    $feedback.text(prefix+(minmax.min?"Min":min)+" - "+
                   prefix+(minmax.max?"Max":max));
    if(!$button.data('unspec-explicit')) {
      if(minmax.min && minmax.max) {
        $tickbox.prop('checked',true);
      } else {
        $tickbox.prop('checked',false);
      }
    }
  }

  function force_blanks($el,val) {
    $('.slider_unspecified input',$el).prop('checked',val);
  }

  function calc_step(kparams,min,max) {
    min = parseFloat(min);
    max = parseFloat(max);
    var step = (max-min)/200;
    if(step === 0) { step = 1; }
    if(kparams.steptype == 'integer') { step = 1; }
    return step;
  }

  function send_update(variety,$button) {
    var $slider = $('.slider',$button);
    var pmin = $slider.slider('option','values.0');
    var pmax = $slider.slider('option','values.1');
    var $tickbox = $('.slider_unspecified input',$button);
    var minmax = is_minmax($button,null,pmin,pmax);
    var update = { nulls: $tickbox.prop('checked') };
    variety.additional_update(update,$button);
    if(!minmax.min) { update.min = pmin; }
    if(!minmax.max) { update.max = pmax; }
    $button.trigger('update',update);
  }

  function draw_slider(variety,$out,$button,min,max,kparams) {
    min = 1*min;
    max = 1*max;
    var step = calc_step(kparams,min,max);
    $button.data('slider-range',[min,max]);
    return $('<div/>').addClass('slider').appendTo($out).slider({
      range: true,
      min: min-step, max: max+step, step: step,
      values: [min-step,max+step],
      slide: function(e,ui) {
        update_widget(variety,$button,$out,ui.values[0],ui.values[1]);
      },
      stop: function(e,ui) {
        send_update(variety,$button);
      }
    });
  }

  function draw_widget(variety,$button,min,max,kparams) {
    var $out = $("<div/>").addClass('newtable_range');
    $('<div/>').addClass('slider_feedback').appendTo($out);
    var $unspec = $('<div/>').addClass('slider_unspecified');
    $unspec.append("<span>include blank / other chrs.</span>");
    var $tickbox = $('<input type="checkbox"/>').appendTo($unspec);
    draw_slider(variety,$out,$button,min,max,kparams);
    $unspec.appendTo($out);
    $tickbox.on('click',function() {
      $button.data('unspec-explicit',true);
      send_update(variety,$button);
    }).prop('checked',true);
    update_widget(variety,$button,$out,null,null);
    return $out;
  }

  function slider_update_size($el,$slider,min,max,kparams) {
    var step = calc_step(kparams,min,max);
    $slider.slider('option','min',parseFloat(min)-step);
    $slider.slider('option','max',parseFloat(max)+step);
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
        display: function($menu,$el,values,state,kparams) {
          values = variety.preproc_values(values);
          var $slider = $('.slider',$menu);
          if($slider.length) {
            var minmax = is_minmax($el,$slider,null,null);
            if(variety.detect_catastrophe($el,$slider,values)) {
              slider_update_size($el,$slider,values.min,values.max,kparams);
              slider_set_minmax($slider,0);
              slider_set_minmax($slider,1);
              update_widget(variety,$el,$menu,null,null);
              force_blanks($menu,true);
              send_update(variety,$el);
            } else {
              slider_update_size($el,$slider,values.min,values.max,kparams);
              if(minmax.min) { slider_set_minmax($slider,0); }
              if(minmax.max) { slider_set_minmax($slider,1); }
            }
          } else {
            var $out = draw_widget(variety,$el,values.min,values.max,kparams);
            variety.draw_additional($el,values);
            $menu.empty().append($out);
            update_widget(variety,$el,$menu,null,null);
          }
        },
        text: function(state,all) {
          var no_blanks = (state.hasOwnProperty('nulls') && !state.nulls);
          var has_min = state.hasOwnProperty('min');
          var has_max = state.hasOwnProperty('max');
          var out;
          if(!has_min && !has_max) {
            out = "All";
            if(no_blanks) { out += " except blank/other"; }
            return out;
          } else {
            out = variety.text_prefix(state)+(has_min?state.min:"Min") +
                  " - " +
                  variety.text_prefix(state)+(has_max?state.max:"Max");
            if(!no_blanks) { out += " or blank/other"; }
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
