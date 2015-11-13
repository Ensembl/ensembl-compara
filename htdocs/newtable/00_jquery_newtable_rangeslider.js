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
  function calc_step(options,min,max) {
    min = parseFloat(min);
    max = parseFloat(max);
    var step = (max-min)/200;
    if(step===0) { step = 1; }
    if(options.integer) { step = 1; }
    return step;
  }

  function slide_stop($this,callback) {
    return function(e,ui) {
      var options = $this.data('options');
      var min = ui.values[0];
      var max = ui.values[1];
      if(!options.fixed) {
        if(min == $this.slider('option','min')) { min = null; }
        if(max == $this.slider('option','max')) { max = null; }
      }
      callback(min,max);
    }
  }

  var defaults = {
    fixed: false,
    integer: false
  };

  var methods = {
    init : function(options) {
      options = $.extend({},defaults,options);
      options.step = calc_step(options,options.min,options.max);
      var smin = options.fixed?options.min:options.min-options.step;
      var smax = options.fixed?options.max:options.max+options.step;
      this.each(function() {
        $(this).addClass('slider').data('options',options).slider({
          range: true, step: options.step,
          min: smin, max: smax, values: [smin,smax],
          slide: slide_stop($(this),options.slide),
          stop: slide_stop($(this),options.stop),
        });
      });
    },
    get: function() {
      var options = this.data('options');
      var val = this.slider('option','values').slice();
      if(!options.fixed) {
        if(val[0] == this.slider('option','min')) { val[0] = null; }
        if(val[1] == this.slider('option','max')) { val[1] = null; }
      }
      return val;
    },
    set: function(min,max) {
      var val = this.slider('option','values')||[];
      if(min===null) { val[0] = this.slider('option','min'); }
      else if(min!==undefined) { val[0] = min; }
      if(max===null) { val[1] = this.slider('option','max'); }
      else if(max!==undefined) { val[1] = max; }
      this.slider('option','values',[parseFloat(val[0]),parseFloat(val[1])]);
    },
    get_limits: function() {
      var options = this.data('options');
      var adj = options.fixed?0:options.step;
      return [this.slider('option','min')+adj,
              this.slider('option','max')-adj];
    },
    set_limits: function(min,max) {
      var options = this.data('options');
      var adj = options.fixed?0:options.step;
      if(min!==undefined) {
        this.slider('option','min',parseFloat(min)-adj);
      }
      if(max!==undefined) {
        this.slider('option','max',parseFloat(max)+adj);
      }
    },
    options: function() { return this.data('options'); },
  };

  $.fn.rangeslider = function(arg) {
    if(methods[arg]) {
      var params = Array.prototype.slice.call(arguments,1);
      return methods[arg].apply(this,params);
    } else if(typeof arg === 'object' || !arg) {
      return methods.init.apply(this,arguments);
    } else {
      $.error('No such method '+arg);
    }    
  };
})(jQuery);
