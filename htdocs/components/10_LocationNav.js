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

  currentLocation: function() { // extract r=, in easy to use format
    var url = window.location[Ensembl.locationURL];
    var url_r = decodeURIComponent(url.match(Ensembl.locationMatch)[1]);
    var r_parts = url_r.match(/^(.*):(.*)-(.*)/);
    return [r_parts[1],parseInt(r_parts[2]),parseInt(r_parts[3])];
  },

  urlNewLocation: function(r) { // current url as string, but with new r=
    var url = window.location.href;
    return url.replace(/([#?;&])r=([^;&]+)/,'$1r='+r);
  },

  arrow: function(step) { // href for arrow buttons at cur pos. as string
    var r = this.currentLocation();
    return this.urlNewLocation(r[0]+':'+(r[1]+step)+'-'+(r[2]+step));  
  },

  zoom: function(factor) { // href for +/- buttons at cur pos. as string
    var r = this.currentLocation();
    var centre = (r[1] + r[2])/2;
    var width = r[2] - r[1];
    var start = Math.round(centre-width*factor/2);
    var end = Math.round(start + width*factor);
    if(start == end && factor > 1) { end += 1; } // enable zoom out from 1bp
    return this.urlNewLocation(r[0]+':'+start+'-'+end);
  },

  updateButtons: function() { // update button hrefs (and loc) at cur. pos
    var panel = this;

    var r = this.currentLocation();
    var width = r[2]-r[1]+1;
    $('.left_2',panel.el).attr('href',panel.arrow(-1e6));
    $('.left_1',panel.el).attr('href',panel.arrow(-width));
    $('.zoom_in',panel.el).attr('href',panel.zoom(0.5));
    $('.zoom_out',panel.el).attr('href',panel.zoom(2));
    $('.right_1',panel.el).attr('href',panel.arrow(width));
    $('.right_2',panel.el).attr('href',panel.arrow(1e6));
    $('#loc_r',panel.el).val(r[0]+':'+r[1]+'-'+r[2]);
  },

  val2pos: function () { // from 0-100 on UI slider to bp
    var panel = this;

    var r = this.currentLocation();
    var input = r[2]-r[1]+1;
    var sliderConfig = $.parseJSON($('span.ramp', panel.el).text());
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

    var sliderConfig = $.parseJSON($('span.ramp', panel.el).text());
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
    var sliderConfig = $.parseJSON($('span.ramp', this.el).text());
    var sliderLabel  = $('.slider_label', this.el);
    
    $('.slider_wrapper', this.el).children().css('display', 'inline-block');
    var slide_min = sliderConfig.min;
    var slide_max = sliderConfig.max;
    var slide_mul = ( Math.log(slide_max) - Math.log(slide_min) ) / 100;
    var slide_off = Math.log(slide_min);
    var r = panel.currentLocation();
    var chr = r[0];
    var r_2centre = Math.round(r[1]+r[2]);
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
        var r_start = Math.round((r_2centre-input)/2);
        var r = chr+':'+r_start+'-'+(r_start+input+1);
        var url = panel.urlNewLocation(r);
        
        if (panel.enabled === false) {
          Ensembl.redirect(url);
          return false;
        } else if (Ensembl.locationURL === 'hash' && !window.location.hash.match(Ensembl.locationMatch) && window.location.search.match(Ensembl.locationMatch)[1] === r) {
          return false; // when there's no hash, but the current location is the same as the new r
        } else if ((window.location[Ensembl.locationURL].match(Ensembl.locationMatch) || [])[1] === r) {
          return false;
        }
        
        Ensembl.updateLocation(r);
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
