// $Revision$

Ensembl.Panel.LocationNav = Ensembl.Panel.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    Ensembl.EventManager.register('ajaxComplete', this, function () { this.enabled = true; });
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
      var r    = hash.match(/[\?;]r=([^;]+)/)[1].split(/\W/);
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
    
    sliderLabel.show();
    
    $('div.slider', this.el).css('display', 'inline-block').slider({
      value: sliderConfig.filter('.selected').index(),
      step:  1,
      min:   0,
      max:   sliderConfig.length - 1,
      slide: function (e, ui) {
        sliderLabel.html(sliderConfig.get(ui.value).name).show();
      },
      change: function (e, ui) {
        var input = sliderConfig.get(ui.value);
        var url   = input.href;
        var r     = input.href.match(/[\?;]r=([^;]+)/)[1];
        
        sliderLabel.html(input.name);
        
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
        
        myself.getContent();
        
        Ensembl.EventManager.trigger('locationChange', r, myself.id, 1);
      }
    });
  },
  
  getContent: function () {    
    $.ajax({
      url: Ensembl.urlFromHash(this.elLk.updateURL.val() + ';update_panel=1'),
      dataType: 'json',
      context: this,
      success: function (json) {
        this.elLk.updateURL.val(json.shift());
        
        this.elLk.regionInputs.each(function () {
          this.value = json.shift();
        });
        
        this.elLk.navLinks.not('.ramp').each(function () {
          this.href = this.href.replace(/([\?;]r=)[^;]+(;?)/, '$1' + json.shift() + '$2');
        });
      }
    });
  }
});
