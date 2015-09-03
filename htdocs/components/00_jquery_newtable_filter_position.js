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

  function update_widget($button,$el,min,max) {
    var $feedback = $('.slider_feedback',$el);
    var $slider = $('.slider',$el);
    var $tickbox = $('.slider_unspecified input',$el);
    var chr = $button.data('slider-chr');
    var minmax = is_minmax($button,null,min,max);
    $feedback.text(chr+':'+(minmax.min?"Min":min)+" - "+
                   chr+':'+(minmax.max?"Max":max));
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
    if(step == 0) { step = 1; }
    if(kparams.steptype == 'integer') { step = 1; }
    return step;
  }

  function send_update($button) {
    var $slider = $('.slider',$button);
    var pmin = $slider.slider('option','values.0');
    var pmax = $slider.slider('option','values.1');
    var $tickbox = $('.slider_unspecified input',$button);
    var minmax = is_minmax($button,null,pmin,pmax);
    var update = {
      nulls: $tickbox.prop('checked'),
      chr: $button.data('slider-chr')
    };
    if(!minmax.min) { update.min = pmin; }
    if(!minmax.max) { update.max = pmax; }
    console.log("UPDATE",update);
    $button.trigger('update',update);
  }

  function draw_slider($out,$button,min,max,kparams) {
    min = 1*min;
    max = 1*max;
    var step = calc_step(kparams,min,max);
    $button.data('slider-range',[min,max]);
    return $('<div/>').addClass('slider').appendTo($out).slider({
      range: true,
      min: min-step, max: max+step, step: step,
      values: [min-step,max+step],
      slide: function(e,ui) {
        update_widget($button,$out,ui.values[0],ui.values[1]);
      },
      stop: function(e,ui) {
        send_update($button);
      }
    });
  }

  function draw_widget($button,min,max,kparams) {
    var $out = $("<div/>").addClass('newtable_range');
    var $feedback = $('<div/>').addClass('slider_feedback').appendTo($out);
    var $unspec = $('<div/>').addClass('slider_unspecified');
    $unspec.append("<span>include blank / other chrs.</span>");
    var $tickbox = $('<input type="checkbox"/>').appendTo($unspec);
    var $slider = draw_slider($out,$button,min,max,kparams);
    $unspec.appendTo($out);
    $tickbox.on('click',function() {
      $button.data('unspec-explicit',true);
      send_update($button);
    }).prop('checked',true);
    update_widget($button,$out,null,null);
    return $out;
  }

  function find_best(values) {
    var best = null;
    $.each(values,function(name,value) {
      if(value.best) { best = value; }
    });
    return best;
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

  $.fn.newtable_filter_position = function(config,data) {
    return {
      filters: [{
        name: "position",
        display: function($menu,$el,values,state,kparams) {
          var best = find_best(values);
          var $slider = $('.slider',$menu);
          if($slider.length) {
            var minmax = is_minmax($el,$slider,null,null);
            if(best.chr != $el.data('slider-chr') && (!minmax.min || !minmax.max)) {
              // Chromosome changed! Panic!
              console.log("CATASTROPHE");
              $el.data('slider-chr',best.chr);
              slider_update_size($el,$slider,best.min,best.max,kparams);
              slider_set_minmax($slider,0);
              slider_set_minmax($slider,1);
              update_widget($el,$menu,null,null);
              force_blanks($menu,true);
              send_update($el);
            } else {
              // Same chromosome
              slider_update_size($el,$slider,best.min,best.max,kparams);
              if(minmax.min) { slider_set_minmax($slider,0); }
              if(minmax.max) { slider_set_minmax($slider,1); }
            }
          } else {
            // New
            $el.data('slider-chr',best.chr);
            var $out = draw_widget($el,best.min,best.max,kparams);
            $menu.empty().append($out);
          }
        },
        text: function(state,all) {
          var no_blanks = (state.hasOwnProperty('nulls') && !state.nulls);
          var has_min = state.hasOwnProperty('min');
          var has_max = state.hasOwnProperty('max');
          if(!has_min && !has_max) {
            var out = "All";
            if(no_blanks) { out += " except blank/other"; }
            return out;
          } else {
            var out = state.chr+':'+((has_min?state.min:"Min") + " - " +
                      state.chr+':'+(has_max?state.max:"Max"));
            if(!no_blanks) { out += " or blank/other"; }
            return out;
          }
        },
        visible: function(values) {
          return values && !obj_empty(values);
        }
      }]
    };
  };
})(jQuery);
