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
  function update_widget($button,$el,min,max,nulls) {
    var $feedback = $('.slider_feedback',$el);
    var $slider = $('.slider',$el);
    var $tickbox = $('.slider_unspecified input',$el);
    var range = $button.data('slider-range');
    var is_min = (min < range[0]);
    var is_max = (max > range[1]);
    $feedback.text((is_min?"Min":min)+" - "+(is_max?"Max":max));
    if(!$button.data('unspec-explicit')) {
      if(is_min && is_max) {
        $tickbox.prop('checked',true);
      } else {
        $tickbox.prop('checked',false);
      }
    }
  }

  function slider($button,min,max,vmin,vmax,nulls,kparams,fn) {
    var $out = $("<div/>").addClass('newtable_range');
    var $feedback = $('<div/>').addClass('slider_feedback').appendTo($out);
    var $unspec = $('<div/>').addClass('slider_unspecified');
    $unspec.append("<span>include blank</span>");
    var $tickbox = $('<input type="checkbox"/>').appendTo($unspec);
    min = parseFloat(min);
    max = parseFloat(max);
    var step = (max-min)/200;
    if(step == 0) { step = 1; }
    if(vmin===null) { vmin = min-step; }
    if(vmax===null) { vmax = max+step; }
    vmin = parseFloat(vmin);
    vmax = parseFloat(vmax);
    if(kparams.steptype == 'integer') { step = 1; }
    var $slider = $('<div/>').addClass('slider').appendTo($out).slider({
      range: true,
      min: min-step, max: max+step, step: step,
      values: [vmin,vmax],
      slide: function(e,ui) {
        update_widget($button,$out,ui.values[0],ui.values[1]);
      },
      stop: function(e,ui) {
        var pmin = ui.values[0];
        var pmax = ui.values[1];
        if(pmin < min) { pmin = null; }
        if(pmax > max) { pmax = null; }
        fn(pmin,pmax,$tickbox.prop('checked'));
      }
    });
    $unspec.appendTo($out);
    $tickbox.on('click',function() {
      $button.data('unspec-explicit',true);
        var pmin = $slider.slider('option','values.0');
        var pmax = $slider.slider('option','values.1');
        if(pmin < min) { pmin = null; }
        if(pmax > max) { pmax = null; }
        fn(pmin,pmax,$tickbox.prop('checked'));
    }).prop('checked',nulls);
    update_widget($button,$out,vmin-step,vmax+step);
    return $out;
  }

  $.fn.newtable_filter_range = function(config,data) {
    return {
      filters: [{
        name: "range",
        display: function($menu,$el,values,state,kparams) {
          if(!$el.data('slider-set')) {
            if(values.hasOwnProperty('min')) {
              $el.data('slider-minp',true);
              $el.data('slider-maxp',true);
              $el.data('slider-min',null);
              $el.data('slider-max',null);
              $el.data('slider-nulls',true);
            } else {
              return "";
            }
          }
          var vmin = $el.data('slider-min');
          var vmax = $el.data('slider-max');
          $el.data('slider-range',[values.min,values.max]);
          var vnulls = $el.data('slider-nulls');
          var $out = slider($el,values.min,values.max,vmin,vmax,
                            vnulls,kparams,function(min,max,nulls) {
              console.log(min,max,nulls);
              $el.data('slider-minp',min===null);
              $el.data('slider-maxp',max===null);
              $el.data('slider-min',min);
              $el.data('slider-max',max);
              $el.data('slider-nulls',nulls);
              $el.data('slider-set',true);
              var update = { nulls: $el.data('slider-nulls') };
              if(min!==null) { update.min = $el.data('slider-min'); }
              if(max!==null) { update.max = $el.data('slider-max'); }
              $el.trigger('update',update);
            });
          $menu.empty().append($out);
        },
        text: function(state,all) {
          var no_blanks = (state.hasOwnProperty('nulls') && !state.nulls);
          var has_min = state.hasOwnProperty('min');
          var has_max = state.hasOwnProperty('max');
          if(!has_min && !has_max) {
            var out = "All";
            if(no_blanks) { out += " except blank"; }
            return out;
          } else {
            var out = ((has_min?state.min:"Min") + " - " +
                      (has_max?state.max:"Max"));
            if(!no_blanks) { out += " or blank"; }
            return out;
          }
        },
        visible: function(values) {
          return values && values.hasOwnProperty('min');
        }
      }]
    };
  };
})(jQuery);
