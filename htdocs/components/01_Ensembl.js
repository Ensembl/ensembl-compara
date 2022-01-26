/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

var Ensembl = new Base();

Ensembl.extend({
  constructor: null,
  
  initialize: function () {
    var hints       = this.cookie.get('ENSEMBL_HINTS');
    var imagePanels = $('.image_panel');
    var modalOpen   = window.location.hash.match(/(modal_.+)/);    
    
    if (!window.name) {
      window.name = 'ensembl_' + new Date().getTime() + '_' + Math.floor(Math.random() * 10000);
    }

    this.setSpecies();

    this.locationURL        = typeof window.history.pushState === 'function' ? 'search' : 'hash';
    this.hashParamRegex     = '([#?;&])(__PARAM__=)[^;&]+((;&)?)';
    this.locationMatch      = new RegExp(/[#?;&]r=([^;&]+)/);
    this.markLocationMatch  = new RegExp(/[#?;&]mr=([^;&]+)/);
    this.locationReplace    = new RegExp(this.hashParamRegex.replace('__PARAM__', 'r'));
    this.width              = parseInt(this.cookie.get('ENSEMBL_WIDTH'), 10) || this.setWidth(undefined, 1);
    this.dynamicWidth       = !!this.cookie.get('DYNAMIC_WIDTH');
    this.hideHints          = {};
    this.initialPanels      = $('.initial_panel');
    this.minWidthEl         = $('#min_width_container');
    this.maxRegionLength    = parseInt($('#max_region_length').val() || 0, 10);
    this.images             = { total: imagePanels.length, last: imagePanels.last()[0] }; // Store image panel details for highlighting
    this.markedLocation     = this.getMarkedLocation();
    this.lastMarkedLocation = false;

    this.browser = (function(ua) {
      var b = {};
      if (ua.match(/webkit/i)) {
        b.webkit = true;
        if (ua.match(/chrome/i)) {
          b.chrome = true;
        } else if (ua.match(/safari/i)) {
          b.safari = true;
        }
      } else if (ua.match(/firefox/)) {
        b.firefox = true;
      } else if (ua.match(/msie|trident/i)) {
        b.ie = true;
      }
      return b;
    })(navigator.userAgent || '');

    if (this.dynamicWidth && !window.name.match(/^popup_/)) {
      var width = this.imageWidth();
      
      if (width > 0 && this.width !== width) {
        this.width = width;
        this.cookie.set('ENSEMBL_WIDTH', width);
      }
    }

    if (hints) {
      $.each(hints.split(/:/), function () {
        Ensembl.hideHints[this] = 1;
      });
    }
        
    imagePanels = null;
    
    this.setCoreParams();
    
    this.LayoutManager.initialize();
    
    // If there's a hash in the URL with a new location in it, and the browser supports history API,
    // update window.location.search to contain the new location.
    // Also change all ajax_load values, so panels are loaded matching the new location.
    var removeHash = this.locationURL === 'hash' ? '' : window.location.hash.match('=');
    var hashChange = removeHash ? window.location.hash.match(this.locationMatch) : false;
    
    $('input.ajax_load').val(function (i, val) { return Ensembl.urlFromHash(val); });
    
    if (removeHash) {
      window.history.replaceState({}, '', Ensembl.urlFromHash(window.location.search));
    }
    
    this.PanelManager.initialize();
    
    if (modalOpen) {
      this.EventManager.deferTrigger('modalOpen', { className: 'force', rel: modalOpen[1] });
      window.location.hash = '';
    }
    
    if (hashChange) {
      this.EventManager.trigger('hashChange', hashChange[1]); // update links and HTML for the new location
    }
  },

  setSpecies: function () {
    this.speciesPath        = $('#species_path').val()        || '';
    this.speciesCommon      = $('#species_common_name').val() || '';
    this.speciesImagePath   = $('#ensembl_image_root').val() + 'species/' || '';
    this.species            = this.speciesPath.split('/').pop();
    this.speciesImage       = $('#ensembl_species_image').val();
  },

  cookie: {
    set: function (name, value, expiry, unescaped, all_sites) {
      var domain = null;
      // all_sites is set to true if you want the cookie to be set for all sites (*.ebi.ac.uk)
      if (all_sites) {
        var re = new RegExp(/(.*?)\.?([^\.]*?)\.(ac\.uk|org)$/);
        var _match = document.domain.match(re);
        if (_match) {
          domain = _match[2] ? _match[2] + "." + _match[3] : document.domain;
        }
      }

      var cookie = [
        unescaped === true ? (name + '=' + (value || '')) : (escape(name) + '=' + escape(value || '')),
        (domain?'; domain='+ domain:'') +'; expires=',
        ((expiry === -1 || value === '') ? 'Thu, 01 Jan 1970 00:00:00 GMT' : expiry ? expiry : 'Tue, 19 Jan 2038 00:00:00 GMT'),
        '; path=/'
      ].join('');

      document.cookie = cookie;
      
      return value;
    },
    
    get: function (name, unescaped) {
      var cookie = document.cookie.match(new RegExp('(^|;)\\s*' + (unescaped === true ? name : escape(name)) + '=([^;\\s]*)'));
      return cookie ? unescape(cookie[2]) : '';
    }
  },
  
  imageWidth: function () {
    return Math.floor(($(window).width() - 240) / 100) * 100;
  },
  
  setWidth: function (w, changed) {
    var numeric = !isNaN(w);
    
    w = numeric ? w : this.imageWidth();
    
    this.width = w < 500 ? 500 : w;
    
    if (changed) {
      this.cookie.set('ENSEMBL_WIDTH', this.width);
      this.cookie.set('DYNAMIC_WIDTH', numeric ? '' : 1);
      this.dynamicWidth = !numeric;
    }
    
    return this.width;
  },
  
  setCoreParams: function () {
    var regex       = '[#?;&]%s=([^;&]+)';
    var url         = window.location.search;
    var hash        = window.location.hash;
    var locationURL = this.locationURL === 'hash' ? hash : url;
    var lastR       = this.coreParams ? this.coreParams.r : '';
    var match, m, i, r;
    
    this.hash         = hash;
    this.coreParams   = {};
    this.initialR     = $('input[name=r]', '#core_params').val();
    this.location     = { length: 100000 };
    this.multiSpecies = {};
    
    $('input', '#core_params').each(function () {
      var hashMatch = locationURL.match(regex.replace('%s', this.name));
      Ensembl.coreParams[this.name] = hashMatch ? unescape(hashMatch[1]) : this.value;
    });
    
    this.lastR = lastR || (hash ? this.coreParams.r : this.initialR);
    
    match = this.coreParams.r ? this.coreParams.r.match(/(.+):(\d+)-(\d+)/) : false;
    
    if (match) {
      this.location = { name: match[1], start: parseInt(match[2], 10), end: parseInt(match[3], 10) };
      this.location.length = this.location.end - this.location.start + 1;
    }
    
    match = url.match(/s\d+=([^;&]+)/g);
    
    if (match) {
      $.each(match, function () {
        m = this.split('=');
        i = m[0].substr(1);
        
        Ensembl.multiSpecies[i] = {};
        
        $.each(['r', 'g', 's'], function (j, param) {
          Ensembl.multiSpecies[i][param] = url.match(regex.replace('%s', param + i));
          
          if (Ensembl.multiSpecies[i][param]) {
            Ensembl.multiSpecies[i][param] = unescape(Ensembl.multiSpecies[i][param][1]);
          }
          
          if (param === 'r' && Ensembl.multiSpecies[i].r) {
            r = Ensembl.multiSpecies[i].r.match(/(.+):(\d+)-(\d+)/);
            
            Ensembl.multiSpecies[i].location = { name: r[1], start: parseInt(r[2], 10), end: parseInt(r[3], 10) };
          }
        });
      });
    }
  },

  changeCoreParam: function (param, value) {
    var inp = $('#core_params input[name=' + param + ']');

    if (!inp.length) {
      inp = $('<input name=' + param + '>').appendTo($('#core_params'));
    }

    if (value === false) {
      inp.remove();
    } else {
      inp.val(value);
    }
  },

  cleanURL: function (url) {
    return url.replace(/&/g, ';').replace(/#.*$/g, '').replace(/([?;])time=[^;]+;?/g, '$1').replace(/[?;]$/g, '');
  },
  
  // Remove the old time stamp from a URL and replace with a new one
  replaceTimestamp: function (url) {
    var d    = new Date();
    var time = d.getTime() + d.getMilliseconds() / 1000;
    
    url  = this.cleanURL(url);
    url += (url.match(/\?/) ? ';' : '?') + 'time=' + time;
    
    return url;
  },

  prepareRequestParams: function (url, decode) {
    var data = {};
    var type;

    url = decode && decodeURIComponent(url) || url;

    if(url.length > 1500 || decode){
      $.each((url.split(/\?/)[1] || '').split(/&|;/), function(i, param) {
        param = param.split('=');
         if (typeof param[0] !== 'undefined' && !(param[0] in data)) {
           data[param[0]] = param[1];
         }
      });
      url  = url.split(/\?/)[0];
      type = 'POST';
    }
    else {
      url  = this.replaceTimestamp(url);
      type = 'GET';
    }

    return {
        requestURL: url,
        requestType: type,
        requestData: data
      };

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
  
  updateLocation: function (r) {
    this.historyReady = true;
    
    if (this.updateURL({ r: r }) === true && this.locationURL === 'search') {
      this.setCoreParams();
      this.EventManager.trigger('hashChange', r);
    }
  },

  getMarkedLocation: function(url) {
    var r = ((url || window.location.href).match(this.markLocationMatch) || ['']).pop().match(/(.+):(\d+)-(\d+)/);

    return r ? [ r[0], r[1], parseInt(r[2]), parseInt(r[3]) ] : null;
  },

  markLocation: function (r) {

    if (r && typeof r === 'string') { // r can be false to clear marked area, or can be an object already
      r = this.getMarkedLocation(r);
    }

    if (r || r === false) {
      this.updateURL({ mr: r && r[0] });
      this.changeCoreParam('mr', r[0]);
      this.setCoreParams();
      this.lastMarkedLocation = this.markedLocation || this.lastMarkedLocation;
      this.markedLocation     = r;
      this.EventManager.trigger('markLocation', r);
    }
  },
  
  updateURL: function (params, inputURL) {
    var url = inputURL || window.location[this.locationURL];
    if (!url.match(/\?/)) {
      url += '?';
    }
    
    for (var i in params) {
      if (params[i] === false) {
        url = url.replace(new RegExp(this.hashParamRegex.replace('__PARAM__', i)), '$1');
      } else if (url.match(new RegExp('[#?;&]' + i + '='))) {
        var regex = new RegExp(this.hashParamRegex.replace('__PARAM__', i));
        
        if (url.match(regex)) {
          url = url.replace(regex, '$1$2' + params[i] + '$3');
        } else {
          url = url.replace(i + '=', i + '=' + params[i]);
        }
      } else {
        url += (url ? ';' : '') + i + '=' + params[i];
      }
    }
    
    url = url.replace(/([?;]);+/g, '$1').replace(/[?;&]$/, '');
    
    if (inputURL) {
      return url;
    }
    
    if (this.locationURL === 'hash') {
      url = url.replace(/^\?/, '');
      if (window.location.hash !== url) {
        window.location.hash = url;
        return true;
      }
    } else if (window.location.search !== url) {
      window.history.pushState({}, '', url);
      return true;
    }
  },
  
  urlFromHash: function (url, paramOnly) {
    var location = window.location[this.locationURL].replace(/^#/, '?') + ';';
    var match    = location.match(this.locationMatch);
    var r        = match ? match[1] : this.initialR || '';
    
    if (paramOnly) {
      return r;
    }

    var hash = r && this.locationURL === 'search' ? { r: r } : {};

    if (hash.r) {
      $.each(['g', 'db', 'mr'], function (i, param) {
        if (Ensembl.coreParams[param]) {
          hash[param] = Ensembl.coreParams[param];
        }
      });
    }

    $.each(window.location.hash.replace('#', '').split(/[;&]/), function () {
      var param = this.split('=');
      
      if (param.length === 2) {
        hash[param[0]] = param[1]; 
      }
    });
    
    return this.updateURL(hash, url);
  },
  
  thousandify: function (str) {
    str += '';
    
    var rgx = /(\d+)(\d{3})/;
    var x   = str.split('.');
    var x1  = x[0];
    var x2  = x.length > 1 ? '.' + x[1] : '';
    
    while (rgx.test(x1)) {
      x1 = x1.replace(rgx, '$1' + ',' + '$2');
    }
    
    return x1 + x2;
  },
  openMotifWidget: function(motifID) {
    var widgetWindow = window.open("/motifWidget.htm?id="+motifID, "Motif Feature Widget", "width=950,height=550");
  },

  populateTemplate : function(template, data) {
    var regexp  = /\{\{[\.\w]+\}\}/g;
    var matches = [];

    var match;
    while ((match = regexp.exec(template)) != null) {
      matches.push({str: match[0], index: match.index});
    }

    var output = [];
    for (var i = matches.length - 1; i >= 0; i--) {
      var match = matches[i].str.replace(/\{|\}/g, '');
      try {
        var replacement = (function(pointer, keys) {
          while (keys.length) {
            var key = keys.shift();
            if (key in pointer) {
              pointer = pointer[key];
            } else {
              throw Error("Missing key '" + key + "'");
            }
          }
          return pointer;
        })(data, match.split('.'));
      } catch (ex) {
        throw Error("Ensembl.populateTemplate could not parse '" + match + "': " + ex.message);
      }

      output.unshift(template.substring(matches[i].index + matches[i].str.length));
      output.unshift(replacement);
      template = template.substr(0, matches[i].index);
    }
    output.unshift(template);
    return output.join('');
  }
});

Ensembl.Class = {}; // sub namespace for "Base" based classes to keep Ensembl in their namespace

window.Ensembl = Ensembl; // Make Ensembl namespace available on window - needed for upload iframes because the minifier will compress the variable name Ensembl
