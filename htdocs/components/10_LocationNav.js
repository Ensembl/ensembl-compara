// $Revision$

Ensembl.Panel.LocationNav = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    this.matchRegex   = new RegExp(/[\?;&]r=([^;&]+)/);
    this.replaceRegex = new RegExp(/([\?;&]r=)[^;&]+(;&?)/);
    
    Ensembl.EventManager.register('ajaxComplete', this, function () { this.enabled = true; });
    Ensembl.EventManager.register('locationChange', this, this.getContent);
  },
  
  init: function () {
    var myself = this;
    
    this.base();
    
    this.enabled = false;
    
    var sliderConfig = $('span.ramp', this.el).hide().children();
    var sliderLabel  = $('.slider_label', this.el);
    
    this.elLk.updateURL    = $('.update_url', this.el);
    this.elLk.regionInputs = $('.location_selector', this.el);
    this.elLk.navLinks     = $('a', this.el).addClass('constant');
    
    if (window.location.hash) {
      this.getContent();
    
      var hash = window.location.hash.replace(/^#/, '?') + ';';
      var r    = hash.match(this.matchRegex)[1].split(/\W/);
      var l    = r[2] - r[1] + 1;
      
      sliderLabel.html(l);
      sliderConfig.removeClass('selected');
      
      var i = sliderConfig.length;
      
      if (l >= parseInt(sliderConfig[i-1].name, 10)) {
        sliderConfig.last().addClass('selected');
      } else {
        var boundaries = $.map(sliderConfig, function (el, i) {
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
    
    $('div.slider', this.el).css('display', 'inline-block').slider({
      value: sliderConfig.filter('.selected').index(),
      step:  1,
      min:   0,
      max:   sliderConfig.length - 1,
      slide: function (e, ui) {
        sliderLabel.html(sliderConfig.get(ui.value).name + ' bp').show();
      },
      change: function (e, ui) {
        var input = sliderConfig.get(ui.value);
        var url   = input.href;
        var r     = input.href.match(myself.matchRegex)[1];
        
        sliderLabel.html(input.name + ' bp');
        
        input = null;
        
        if (myself.enabled === false || window.location.pathname.match(/\/Multi/)) {
          Ensembl.redirect(url);
          return false;
        } else if ((!window.location.hash || window.location.hash == '#') && url == window.location.href) {
          return false;
        } else if (window.location.hash.match('r=' + r)) {
          return false;
        }
        
        window.location.hash = 'r=' + r;
        
        Ensembl.EventManager.trigger('locationChange', r, myself.id, 1);
      },
      stop: function () {
        sliderLabel.hide();
      }
    });
  },
  
  getContent: function () {
    var myself = this;
    
    $.ajax({
      url: Ensembl.urlFromHash(this.elLk.updateURL.val() + ';update_panel=1'),
      dataType: 'json',
      success: function (json) {
        myself.elLk.updateURL.val(json.shift());
        
        myself.elLk.regionInputs.each(function () {
          this.value = json.shift();
        });
        
        myself.elLk.navLinks.not('.ramp').each(function () {
          this.href = this.href.replace(myself.replaceRegex, '$1' + json.shift() + '$2');
        });
      }
    });
  }
});
