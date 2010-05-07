// $Revision$

var Ensembl = new Base();

Ensembl.extend({
  constructor: null,
  
  initialize: function () {
    var myself = this;
    
    var hints = this.cookie.get('ENSEMBL_HINTS');
    
    if (!window.name) {
      window.name = 'ensembl_' + new Date().getTime() + '_' + Math.floor(Math.random() * 10000);
    }
    
    if (window.location.hash) {
      $('.ajax_load').each(function () {
        this.value = myself.urlFromHash(this.value);
      });
    }
    
    (this.ajax  = this.cookie.get('ENSEMBL_AJAX'))  || this.setAjax();
    (this.width = this.cookie.get('ENSEMBL_WIDTH')) || this.setWidth();
    
    this.hideHints = {};
    
    if (hints) {
      $.each(hints.split(/:/), function () {
        myself.hideHints[this] = 1;
      });
    }
    
    var imagePanels = $('.image_panel');
    
    // Store image panel details for highlighting
    this.images = {
      total: imagePanels.length,
      last:  imagePanels.last()[0]
    };
    
    imagePanels = null;
    
    this.setCoreParams();
    
    this.LayoutManager.initialize();
    this.PanelManager.initialize();
  },
   
  cookie: {
    set: function (name, value, expiry, unescaped) {  
      var cookie = [
        unescaped === true ? (name + '=' + (value || '')) : (escape(name) + '=' + escape(value || '')),
        '; expires=',
        (expiry == -1 ? 'Thu, 01 Jan 1970' : 'Tue, 19 Jan 2038'),
        ' 00:00:00 GMT; path=/'
      ].join('');
      
      document.cookie = cookie;
    },
    
    get: function (name, unescaped) {
      var cookie = document.cookie.match(new RegExp('(^|;)\\s*' + (unescaped === true ? name : escape(name)) + '=([^;\\s]*)'));
      return cookie ? unescape(cookie[2]) : '';
    }
  },
  
  setAjax: function () {
    this.cookie.set('ENSEMBL_AJAX', ($.ajaxSettings.xhr() || false) ? 'enabled' : 'none');
  },
  
  setWidth: function () {
    var w = Math.floor(($(window).width() - 250) / 100) * 100;
    
    this.width = w < 500 ? 500 : w;
    this.cookie.set('ENSEMBL_WIDTH', this.width);
  },
  
  setCoreParams: function () {
    var myself = this;
    
    var regex = '[;&?]%s=(.+?)[;&]';
    var url   = window.location.search + ';';
    var hash  = window.location.hash.replace(/^#/, '?') + ';';
    
    this.coreParams   = {};
    this.location     = { width: 100000 };
    this.speciesPath  = $('#species_path').val();
    this.species      = this.speciesPath.split('/').pop();
    this.multiSpecies = {};
    
    $('input', '#core_params').each(function () {
      var hashMatch = hash.match(regex.replace('%s', this.name));
      myself.coreParams[this.name] = hashMatch ? unescape(hashMatch[1]) : this.value;
    });
    
    var match = (this.coreParams.r ? this.coreParams.r.match(/(.+):(\d+)-(\d+)/) : false) || ($('a', '#tab_location').html() || '').replace(/,/g, '').match(/^Location: (.+):(\d+)-(\d+)$/);
    
    if (match) {
      this.location = { name: match[1], start: parseInt(match[2], 10), end: parseInt(match[3], 10) };
      this.location.width = this.location.end - this.location.start + 1;
      
      if (this.location.width > 1000000) {
        this.location.width = 1000000;
      }
    }
    
    match = url.match(/s\d+=.+?[;&]/g);
    
    if (match) {      
      var m, i, r;
      
      $.each(match, function () {
        m = this.split('=');
        i = m[0].substr(1);
        
        myself.multiSpecies[i] = {};
        
        $.each(['r', 'g', 's'], function () {
          myself.multiSpecies[i][this] = url.match(regex.replace('%s', this + i));
          
          if (myself.multiSpecies[i][this]) {
            myself.multiSpecies[i][this] = unescape(myself.multiSpecies[i][this][1]);
          }
          
          if (this == 'r' && myself.multiSpecies[i].r) {
            r = myself.multiSpecies[i].r.match(/(.+):(\d+)-(\d+)/);
            
            myself.multiSpecies[i].location = { name: r[1], start: parseInt(r[2], 10), end: parseInt(r[3], 10) };
          }
        });
      });
    }
  },
  
  cleanURL: function (url) {
    return unescape(url.replace(/&/g, ';').replace(/#.*$/g, '').replace(/([\?;])time=[^;]+;?/g, '$1').replace(/[\?;]$/g, ''));
  },
  
  // Remove the old time stamp from a URL and replace with a new one
  replaceTimestamp: function (url) {
    var d = new Date();
    var time = d.getTime() + d.getMilliseconds() / 1000;
    
    url = this.cleanURL(url);
    url += (url.match(/\?/) ? ';' : '?') + 'time=' + time;
    
    return url;
  },
  
  redirect: function (url) {
    for (var p in this.PanelManager.panels) {
      this.PanelManager.panels[p].destructor('cleanup');
    }
    
    url = url || this.replaceTimestamp(window.location.href);
    
    if (window.location.hash) {
      url = this.urlFromHash(url);
    }
    
    window.location = url;
  },
  
  urlFromHash: function (url) {
    this.hashRegex = this.hashRegex || new RegExp(/[\?;&]r=([^;&]+)/);
    
    var hash = window.location.hash.replace(/^#/, '?') + ';';
    var r    = hash.match(this.hashRegex)[1];
    return url.match(this.hashRegex) ? url.replace(/([\?;]r=)[^;]+(;?)/, '$1' + r + '$2') : url + ';r=' + r;
  }
});
