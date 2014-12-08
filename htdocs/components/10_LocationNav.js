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

Ensembl.Panel.LocationNav = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    Ensembl.EventManager.register('hashChange',  this, this.getContent);
    Ensembl.EventManager.register('changeWidth', this, this.resize);
    Ensembl.EventManager.register('imageResize', this, this.resize);
    
    if (!window.location.pathname.match(/\/Multi/)) {
      Ensembl.EventManager.register('ajaxComplete', this, function () { this.enabled = true; });
    }
  },
    
  config: function() {
    var panel = this;
    var sliderConfig = $.parseJSON($('span.ramp', panel.el).text());
    // TODO cache it? Is it worth it?
    return sliderConfig;
  },

  currentLocations: function() { // extract r's into easy to use format
    var out = {};
    var url = decodeURIComponent(window.location.href).split("?");
    parts = url[1].split(/[;&]/);
    $.each(parts,function(i,part) {
      kv = part.split("=");
      if(!kv[0].match(/^r[0-9]*$/))
        return;
      var r_parts = kv[1].match(/^([^:]*):([^-]*)-([^:]*)(:.*)?/);
      out[kv[0]] = [r_parts[1],parseInt(r_parts[2]),parseInt(r_parts[3]),r_parts[4]||''];
    });
    return out;
  },

  newLocation: function(rs) {
    var url = decodeURIComponent(window.location.href).split("?");
    parts = url[1].split(/[;&]/);
    new_parts = [];
    $.each(parts,function(i,part) {
      kv = part.split("=");
      if(kv[0].match(/^r[0-9]*$/)) {
        new_parts.push(kv[0]+"="+rs[kv[0]][0]+":"+rs[kv[0]][1]+"-"+rs[kv[0]][2]+rs[kv[0]][3]);
      } else {
        new_parts.push(part);
      }
    });
    var extra = $('.image_nav .extra-params',this.el).attr('href');
    if(extra) {
      extra = ';' + extra.substring(1);
    }
    return url[0]+"?"+new_parts.join(";")+extra;
  },

  rescale: function(rs,input) {
    var config = this.config();
    input = Math.round(input);
    var out = {};
    $.each(rs,function(k,v) {
      var r_2centre = Math.round(v[1]+v[2]);
      var r_start = Math.round((r_2centre-input)/2);
      if(r_start<1) { r_start = 1; }
      var r_end = r_start+input+1;
      if(k=='r') {
        if(r_start > config.length) {
          r_start = config.length - config.min;
        }
        if(r_end > config.length) {
          r_end = config.length;
        }
      }
      if(r_start<1) { r_start = 1; }
      out[k] = [v[0],r_start,r_end,v[3]];
    });
    return out;
  },

  arrow: function(step) { // href for arrow buttons at cur pos. as string
    var config = this.config();
    var rs = this.currentLocations();
    var out =  {};
    $.each(rs,function(k,v) {
      v[1] += step;
      v[2] += step;
      if(k=='r') {
        if(v[1] > config.length) { v[1] = config.length - config.min; }
        if(v[2] > config.length) { v[2] = config.length; }
        if(v[1] < 1) { v[1] = 1; }
        if(v[2] < 1) { v[2] = config.min; }
      }
    });
    return this.newLocation(rs);
  },

  zoom: function(factor) { // href for +/- buttons at cur pos. as string
    var rs = this.currentLocations();
    var width = rs['r'][2] - rs['r'][1];
    rs = this.rescale(rs,width*factor);
    if(factor>1) {
      $.each(rs,function(k,v) {
        if(v[1] == v[2]) { v[2]++; }
      });
    }
    return this.newLocation(rs);
  },

  updateButtons: function() { // update button hrefs (and loc) at cur. pos
    var panel = this;

    var rs = this.currentLocations();
    var width = rs['r'][2]-rs['r'][1]+1;
    $('.left_2',panel.el).attr('href',panel.arrow(-1e6));
    $('.left_1',panel.el).attr('href',panel.arrow(-width));
    $('.zoom_in',panel.el).attr('href',panel.zoom(0.5));
    $('.zoom_out',panel.el).attr('href',panel.zoom(2));
    $('.right_1',panel.el).attr('href',panel.arrow(width));
    $('.right_2',panel.el).attr('href',panel.arrow(1e6));
    $('#loc_r',panel.el).val(rs['r'][0]+':'+rs['r'][1]+'-'+rs['r'][2]);
  },

  val2pos: function () { // from 0-100 on UI slider to bp
    var panel = this;

    var rs = this.currentLocations();
    var input = rs['r'][2]-rs['r'][1]+1;
    var sliderConfig = panel.config();
    var slide_min = sliderConfig.min;
    var slide_max = sliderConfig.max;
    var slide_mul = ( Math.log(slide_max) - Math.log(slide_min) ) / 100;
    var slide_off = Math.log(slide_min);
    var out = (Math.log(input)-slide_off)/slide_mul;
    if(out < 0) { return 0; }
    if(out > 100) { return 100; }
    return out;
  }, 

  pos2val: function(pos) { // from bp to 0-100 on UI slider
    var panel = this;

    var sliderConfig = panel.config();
    var slide_min = sliderConfig.min;
    var slide_max = sliderConfig.max;
    var slide_mul = ( Math.log(slide_max) - Math.log(slide_min) ) / 100;
    var slide_off = Math.log(slide_min);
    var raw_value = Math.exp(pos * slide_mul + slide_off);
    // To 2sf
    var mag = Math.pow(10,2 - Math.ceil(Math.log(raw_value)/Math.LN10));
    var value = Math.round(Math.round(raw_value*mag)/mag);
    return value;
  },
 
  init: function () {
    var panel = this;
    
    this.base();
    
    this.enabled = this.params.enabled || false;

    this.elLk.locationInput = $('.location_selector', this.el);
    this.elLk.navbar        = $('.navbar', this.el);
    this.elLk.imageNav      = $('.image_nav', this.elLk.navbar);
    this.elLk.forms         = $('form', this.elLk.navbar);
    
    $('a.go-button', this.elLk.forms).on('click', function () {
      $(this).parents('form').trigger('submit');
      return false;
    });
    
    this.elLk.navLinks = $('a', this.elLk.imageNav).addClass('constant').on('click', function (e) {
      var newR;
      
      if (panel.enabled === true) {
        newR = this.href.match(Ensembl.locationMatch)[1];
        
        if (newR !== Ensembl.coreParams.r) {
          Ensembl.updateLocation(newR);
        }
        
        return false;
      }
    });
    
    if(!$('span.ramp', this.el).length) { return; } // No slider here
    $('span.ramp', this.el).hide();
    var sliderConfig = panel.config();
    var sliderLabel  = $('.slider_label', this.el);
    
    $('.slider_wrapper', this.el).children().css('display', 'inline-block');
    var slide_min = sliderConfig.min;
    var slide_max = sliderConfig.max;
    var slide_mul = ( Math.log(slide_max) - Math.log(slide_min) ) / 100;
    var slide_off = Math.log(slide_min);
    var rs = panel.currentLocations();
    this.elLk.slider = $('.slider', this.el).slider({
      value: panel.val2pos(),
      step:  1,
      min:   0,
      max:   100,
      force: false,
      slide: function (e, ui) {
        var value = panel.pos2val(ui.value);
        sliderLabel.html(value + ' bp').show();
      },
      change: function (e, ui) {
        if(panel.elLk.slider.slider('option','fake')) { return; }
        var input = panel.pos2val(ui.value);
        rs = panel.rescale(rs,input);
        var url = panel.newLocation(rs);
        
        if (panel.enabled === false) {
          Ensembl.redirect(url);
          return false;
        } else if (Ensembl.locationURL === 'hash' && !window.location.hash.match(Ensembl.locationMatch) && window.location.search.match(Ensembl.locationMatch)[1] === rs['r']) {
          return false; // when there's no hash, but the current location is the same as the new r
        } else if ((window.location[Ensembl.locationURL].match(Ensembl.locationMatch) || [])[1] === rs['r']) {
          return false;
        }
        
        Ensembl.updateLocation(rs['r'][0]+":"+rs['r'][1]+"-"+rs['r'][2]);
      },
      stop: function () {
        sliderLabel.hide();
        $('.ui-slider-handle', panel.elLk.slider).trigger('blur'); // Force the blur event to remove the highlighting for the handle
      }
    });
    this.updateButtons(); 
    this.resize();
  },
  
  getContent: function () {
    var panel = this;

    if(panel.elLk.slider) {  
      panel.elLk.slider.slider('option','fake',true); 
      panel.elLk.slider.slider('value',panel.val2pos());
      panel.elLk.slider.slider('option','fake',false); 
      panel.updateButtons();
    }
  },
  
  resize: function () {
    var widths = {
      navbar: this.elLk.navbar.width(),
      slider: this.elLk.imageNav.width(),
      forms:  this.elLk.forms.width()
    };
    
    if (widths.navbar < widths.forms + widths.slider) {
      this.elLk.navbar.removeClass('narrow1').addClass('narrow2');
    } else if (widths.navbar < (widths.forms * this.elLk.forms.length) + widths.slider) {
      this.elLk.navbar.removeClass('narrow2').addClass('narrow1');
    } else {
      this.elLk.navbar.removeClass('narrow1 narrow2');
    }
    this.updateButtons();
  }
});
