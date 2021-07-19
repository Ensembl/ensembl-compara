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
      callback(transform(options,min,1),transform(options,max,1));
    }
  }

  function transform(options,val,inv) {
    if(options.soggy) {
      if(inv) { return Math.pow(val,2); } else { return Math.pow(val,1/2); }
    } else {
      return val;
    }
  }

  var defaults = {
    fixed: false,
    integer: false,
    soggy: false
  };

  var methods = {
    init : function(options) {
      options = $.extend({},defaults,options);
      /* Adjust for soggy start */
      var smin = transform(options,options.min,0);
      var smax = transform(options,options.max,0);
      options.step = calc_step(options,smin,smax);
      /* Adjust for min/max step */
      smin = options.fixed?smin:smin-options.step;
      smax = options.fixed?smax:smax+options.step;
      this.each(function() {
        $(this).addClass('slider').data('options',options).slider({
          range: true, step: options.step,
          min: smin, max: smax, values: [smin,smax],
          slide: slide_stop($(this),options.slide),
          stop: slide_stop($(this),options.stop)
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
      val[0] = transform(options,val[0],1);
      val[1] = transform(options,val[1],1);
      return val;
    },
    set: function(min,max) {
      var options = this.data('options');
      var val = this.slider('option','values').slice()||[];
      if(min===null) { val[0] = this.slider('option','min'); }
      else if(min!==undefined) { val[0] = transform(options,min,0); }
      if(max===null) { val[1] = this.slider('option','max'); }
      else if(max!==undefined) { val[1] = transform(options,max,0); }
      this.slider('option','values',[parseFloat(val[0]),parseFloat(val[1])]);
    },
    get_limits: function() {
      var options = this.data('options');
      var adj = options.fixed?0:options.step;
      return [transform(options,this.slider('option','min')+adj,1),
              transform(options,this.slider('option','max')-adj,1)];
    },
    set_limits: function(min,max) {
      var options = this.data('options');
      var adj = options.fixed?0:options.step;
      if(min!==undefined) {
        this.slider('option','min',transform(options,parseFloat(min),0)-adj);
      }
      if(max!==undefined) {
        this.slider('option','max',transform(options,parseFloat(max),0)+adj);
      }
    },
    options: function() { return this.data('options'); }
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
