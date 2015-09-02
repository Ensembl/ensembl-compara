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
    $feedback.text(min+" - "+max);
    if(!$button.data('unspec-explicit')) {
      var all = (min == $slider.slider('option','min') &&
                max == $slider.slider('option','max'));
      if(all) {
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
    if(kparams.steptype == 'integer') { step = 1; }
    console.log("SLIDER");
    var $slider = $('<div/>').addClass('slider').appendTo($out).slider({
      range: true,
      min: min, max: max, step: step,
      values: [parseFloat(vmin),parseFloat(vmax)],
      slide: function(e,ui) {
        update_widget($button,$out,ui.values[0],ui.values[1]);
      },
      stop: function(e,ui) {
        fn(ui.values[0],ui.values[1],$tickbox.prop('checked'));
      }
    });
    $unspec.appendTo($out);
    $tickbox.on('click',function() {
      $button.data('unspec-explicit',true);
      fn($slider.slider('option','values.0'),
         $slider.slider('option','values.1'),$tickbox.prop('checked'));
    }).prop('checked',nulls);
    update_widget($button,$out,vmin,vmax);
    return $out;
  }

  $.fn.newtable_filter_range = function(config,data) {
    return {
      filters: [{
        name: "range",
        display: function($el,values,state,kparams) {
          if(!$el.data('slider-set')) {
            if(values.hasOwnProperty('min')) {
              $el.data('slider-min',values.min);
              $el.data('slider-max',values.max);
              $el.data('slider-nulls',true);
            } else {
              return "";
            }
          }
          var vmin = $el.data('slider-min');
          var vmax = $el.data('slider-max');
          $el.data('slider-range',[values.min,values.max]);
          var vnulls = $el.data('slider-nulls');
          return slider($el,values.min,values.max,vmin,vmax,vnulls,kparams,
            function(min,max,nulls) {
              console.log(min,max,nulls);
              $el.data('slider-min',min);
              $el.data('slider-max',max);
              $el.data('slider-nulls',nulls);
              $el.data('slider-set',true);
              $el.trigger('update',{
                min: $el.data('slider-min'),
                max: $el.data('slider-max'),
                nulls: $el.data('slider-nulls')
              });
            });
        },
        text: function(state,all) {
          var range = null;
          var no_blanks = (state.hasOwnProperty('nulls') && !state.nulls);
          if(state.hasOwnProperty('min') && state.hasOwnProperty('max')) {
            if(!(all.hasOwnProperty('min') && all.hasOwnProperty('max') &&
                all.min==state.min && all.max==state.max)) {
              var range = state.min+"-"+state.max;
              if(!no_blanks) { range = range + " or blank"; }
              return range;
            }
          }
          range = "All";
          if(no_blanks) { range += " except blank"; }
          return range;
        },
        visible: function(values) {
          return values && values.hasOwnProperty('min');
        }
      }]
    };
  };
})(jQuery);
