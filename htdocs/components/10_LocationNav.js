// $Revision$

Ensembl.Panel.LocationNav = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    this.matchRegex   = new RegExp(/[\?;&]r=([^;&]+)/);
    this.replaceRegex = new RegExp(/([\?;&]r=)[^;&]+(;&?)*/);
    
    Ensembl.EventManager.register('hashChange', this, this.getContent);
    
    if (!window.location.pathname.match(/\/Multi/)) {
      Ensembl.EventManager.register('ajaxComplete', this, function () { this.enabled = true; });
    }
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    this.enabled = this.params.enabled || false;
    this.reload  = false;
    
    var sliderConfig = $('span.ramp', this.el).hide().children();
    var sliderLabel  = $('.slider_label', this.el);
    var hash, boundaries, r, l, i;
    
    this.elLk.updateURL    = $('.update_url', this.el);
    this.elLk.regionInputs = $('.location_selector', this.el);
    this.elLk.navLinks     = $('a', this.el).addClass('constant').bind('click', function (e) {
      if (panel.enabled === true) {
        if ($(this).hasClass('move')) {
          panel.reload = true;
        }
        
        window.location.hash = 'r=' + this.href.match(panel.matchRegex)[1]; 
        return false;
      }
    });
    
    if (window.location.hash) {
      hash = window.location.hash.replace(/^#/, '?') + ';';
      r    = hash.match(this.matchRegex)[1].split(/\W/);
      l    = r[2] - r[1] + 1;
      
      sliderLabel.html(l);
      sliderConfig.removeClass('selected');
      
      i = sliderConfig.length;
      
      if (l >= parseInt(sliderConfig[i-1].name, 10)) {
        sliderConfig.last().addClass('selected');
      } else {
        boundaries = $.map(sliderConfig, function (el, i) {
          return Math.sqrt((i ? parseInt(sliderConfig[i-1].name, 10) : 0) * parseInt(el.name, 10));
        });
        
        boundaries.push(1e30);
        
        while (i--) {
          if (l > boundaries[i] && l <= boundaries[i+1]) {
            sliderConfig.eq(i).addClass('selected');
            break;
          }
        }
      }
    }
    
    $('.slider_wrapper', this.el).children().css('display', 'inline-block');
    
    this.elLk.slider = $('.slider', this.el).slider({
      value: sliderConfig.filter('.selected').index(),
      step:  1,
      min:   0,
      max:   sliderConfig.length - 1,
      force: false,
      slide: function (e, ui) {
        sliderLabel.html(sliderConfig[ui.value].name + ' bp').show();
      },
      change: function (e, ui) {      
        var input = sliderConfig[ui.value];
        var url   = input.href;
        var r     = url.match(panel.matchRegex)[1];
        
        sliderLabel.html(input.name + ' bp');
        
        input = null;
        
        if (panel.elLk.slider.slider('option', 'force') === true) {
          return false;
        } else if (panel.enabled === false) {
          Ensembl.redirect(url);
          return false;
        } else if ((!window.location.hash || window.location.hash == '#') && url == window.location.href) {
          return false;
        } else if (window.location.hash.match('r=' + r)) {
          return false;
        }
        
        window.location.hash = 'r=' + r;
      },
      stop: function () {
        sliderLabel.hide();
        $('.ui-slider-handle', panel.elLk.slider).trigger('blur'); // Force the blur event to remove the highlighting for the handle
      }
    });
  },
  
  getContent: function () {
    var panel = this;
    
    if (this.reload === true) {
      $.ajax({
        url: Ensembl.urlFromHash(panel.elLk.updateURL.val()),
        dataType: 'html',
        success: function (html) {
          Ensembl.EventManager.trigger('addPanel', panel.id, 'LocationNav', html, $(panel.el), { enabled: panel.enabled });
        }
      });
    } else {
      $.ajax({
        url: Ensembl.urlFromHash(this.elLk.updateURL.val() + ';update_panel=1'),
        dataType: 'json',
        success: function (json) {
          var sliderValue = json.shift();
          
          if (panel.elLk.slider.slider('value') != sliderValue) {
            panel.elLk.slider.slider('option', 'force', true);
            panel.elLk.slider.slider('value', sliderValue);
            panel.elLk.slider.slider('option', 'force', false);
          }
        
          panel.elLk.updateURL.val(json.shift());
          
          panel.elLk.regionInputs.val(function () {
            return json.shift();
          });
          
          panel.elLk.navLinks.not('.ramp').attr('href', function () {
            return this.href.replace(panel.replaceRegex, '$1' + json.shift() + '$2');
          });
        }
      });
    }
  }
});
