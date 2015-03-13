/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

Ensembl.LayoutManager = new Base();

Ensembl.LayoutManager.extend({
  constructor: null,
  
  /**
   * Creates events on elements outside of the domain of panels
   */
  initialize: function () {
    this.id = 'LayoutManager';
    
    Ensembl.EventManager.register('reloadPage',    this, this.reloadPage);
    Ensembl.EventManager.register('validateForms', this, this.validateForms);
    Ensembl.EventManager.register('makeZMenu',     this, this.makeZMenu);
    Ensembl.EventManager.register('hashChange',    this, this.hashChange);
    Ensembl.EventManager.register('toggleContent', this, this.toggleContent);
    Ensembl.EventManager.register('changeWidth',   this, this.changeWidth);
        
    $('#page_nav .tool_buttons > p').show();
    
    $('#header a:not(#tabs a)').addClass('constant');
    
    if (window.location.hash.match(Ensembl.locationMatch)) {
      $('.ajax_load').val(function (i, val) {
        return Ensembl.urlFromHash(val);
      });
      
      this.hashChange(Ensembl.urlFromHash(window.location.href, true));
    }
    
    $(document).on('click', '.modal_link', function () {
      if (Ensembl.EventManager.trigger('modalOpen', this)) {
        return false;
      }
    }).on('click', '.popup', function () {
      if (window.name.match(/^popup_/)) {
        return true;
      }
      
      window.open(this.href, 'popup_' + window.name, 'width=950,height=500,resizable,scrollbars');
      return false;
    }).on('click', 'a[rel="external"]', function () { 
      this.target = '_blank';
    }).on('click', 'a.update_panel', function () {
      var panelId = this.rel;
      var url     = Ensembl.updateURL({ update_panel: 1 }, this.href);
 
      if (Ensembl.PanelManager.panels[panelId] && this.href.split('?')[0].match(Ensembl.PanelManager.panels[panelId].params.updateURL.split('?')[0])) {
        var params = {};
        
        if (!$('.update_url', this).add($(this).siblings('.update_url')).each(function () { params[this.name] = this.value; }).length) {
          params = undefined;
        }
        
        Ensembl.EventManager.triggerSpecific('updatePanel', panelId, url, null, { updateURL: this.href }, params);
      } else {
        $.ajax({
          url: url,
          success: function () {
            Ensembl.EventManager.triggerSpecific('updatePanel', panelId);
          }
        });
      }
      
      return false;
    }).on('submit', 'form.update_panel', function (e) {
      var params    = $(this).serializeArray();
      var urlParams = {};
      var panelId, url, el;
      
      for (var i in params) {
        switch (params[i].name) {
          case 'panel_id': panelId = params[i].value; break;
          case 'url'     : url     = params[i].value; break;
          case 'element' : el      = params[i].value; break;
          default        : urlParams[params[i].name] = params[i].value; break;
        }
      }
      
      url = Ensembl.updateURL($.extend({ update_panel: 1 }, urlParams), url);
      
      Ensembl.EventManager.triggerSpecific('updatePanel', panelId, url, el, null, urlParams);
      
      return false;
    }).on({
      'keyup.ensembl': function (event) {
        if (event.keyCode === 27) {
          Ensembl.EventManager.trigger('modalClose', true); // Close modal window if the escape key is pressed
        }
      },
      'mouseup.ensembl': function (e) {
        // only fired on left click
        if (!e.which || e.which === 1) {
          Ensembl.EventManager.trigger('mouseUp', e);
        }
      }
    });
    
    $('.modal_link').show();
    
    this.validateForms(document);
    
    $(window).on({
      'resize.ensembl': function (e) {
        if (window.name.match(/^popup_/)) {
          return false;
        }
        
        // jquery ui resizable events cause window.resize to fire (all events bubble to window)
        // if target has no tagName it is window or document. Don't resize unless this is the case
        if (!e.target.tagName) {
          var width = Ensembl.width;
          
          if (Ensembl.dynamicWidth) {
            Ensembl.setWidth(undefined, true);
          }
          
          Ensembl.cookie.set('WINDOW_WIDTH', $(window).width());	
          Ensembl.EventManager.trigger('windowResize');
          
          if (Ensembl.dynamicWidth && Ensembl.width !== width) {
            Ensembl.LayoutManager.changeWidth();
            Ensembl.EventManager.trigger('imageResize');
          }
        }
      },
      'hashchange.ensembl': $.proxy(this.popState, this),
      'popstate.ensembl'  : $.proxy(this.popState, this)
    });
    
    this.showMobileMessage();
    if (!this.showCookieMessage()) {
      this.handleMirrorRedirect();
    }
  },
  
  reloadPage: function (args, url) {
    if (typeof args === 'string') {
      Ensembl.EventManager.triggerSpecific('updatePanel', args);
    } else if (typeof args === 'object') {
      for (var i in args) {
        Ensembl.EventManager.triggerSpecific('updatePanel', i);
      }
    } else {
      return Ensembl.redirect(url);
    }
    
    $('.session_messages').hide();
  },
  
  validateForms: function (context) {
    $('form._check', context).validate().on('submit', function () {
      var form = $(this);
      
      if (form.parents('#modal_panel').length) {
        var panels = form.parents('.js_panel').map(function () { return this.id; }).toArray();
        var rtn;
        
        while (panels.length && typeof rtn === 'undefined') {
          rtn = Ensembl.EventManager.triggerSpecific('modalFormSubmit', panels.shift(), form);
        }
        
        return rtn;
      }
    });
  },
  
  makeZMenu: function (id, params) {
    if (!$('#' + id).length) {
      Ensembl.Panel.ZMenu.template.clone().attr('id', id).appendTo('body');
    }
    
    Ensembl.EventManager.trigger('addPanel', id, 'ZMenu', undefined, undefined, params, 'showExistingZMenu');
  },
  
  popState: function () {
    if (
      Ensembl.historyReady && // stops popState executing on initial page load in Chrome. This value is set to true in Ensembl.updateLocation
      // there is an r param in the hash/search EXCEPT WHEN the browser supports history API, and there is a hash which doesn't have an r param (ajax added content)
      ((window.location[Ensembl.locationURL].match(Ensembl.locationMatch) && !(Ensembl.locationURL === 'search' && window.location.hash && !window.location.hash.match(Ensembl.locationMatch))) ||
      (!window.location.hash && Ensembl.hash.match(Ensembl.locationMatch))) // there is no location.hash, but Ensembl.hash (previous hash value) had an r param (going back from no hash url to hash url)
    ) {
      Ensembl.setCoreParams();
      Ensembl.EventManager.trigger('hashChange', Ensembl.urlFromHash(window.location.href, true));
    }
  },
  
  hashChange: function (r) {
    if (!r) {
      return;
    }
    
    r = decodeURIComponent(r);
    
    var text = r.split(/\W/);
        text = text[0] + ': ' + Ensembl.thousandify(text[1]) + '-' + Ensembl.thousandify(text[2]);
    
    $('a:not(.constant)').attr('href', function () {
      var r;
      
      if (this.title === 'UCSC') {
        this.href = this.href.replace(/(&?position=)[^&]+(.?)/, '$1chr' + Ensembl.urlFromHash(this.href, true) + '$2');
      } else if (this.title === 'NCBI') {
        r = Ensembl.urlFromHash(this.href, true).split(/[:\-]/);
        this.href = this.href.replace(/(&?CHR=).+&BEG=.+&END=[^&]+(.?)/, '$1' + r[0] + '&BEG=' + r[1] + '&END=' + r[2] + '$2');
      } else {
        return Ensembl.urlFromHash(this.href);
      }
    });
    
    $('input[name=r]', 'form:not(#core_params)').val(r);
    
    $('h1.summary-heading').html(function (i, html) {
      return html.replace(/^(Chromosome ).+/, '$1' + text);
    });
    
    document.title = document.title.replace(/(Chromosome ).+/, '$1' + text);
  },
  
  toggleContent: function (rel, delay) {
    if (rel) {
      window.setTimeout(function() {
        $('a.toggle[rel="' + rel + '"]').toggleClass('open closed');
      }, delay && $('a.toggle[rel="' + rel + '"]').hasClass('open') ? delay : 0);
    }
  },
  
  changeWidth: function () {
    var modal = $('#modal_panel');
    $('.navbar, div.info, div.hint, div.warning, div.error').not('.fixed_width').not(function () { return modal.find(this).length; }).width(Ensembl.width);
    modal = null;
  },
  
  handleMirrorRedirect: function() {
    
    var redirectCode  = unescape(Ensembl.cookie.get('redirect_mirror'));
    var redirectURI   = unescape(Ensembl.cookie.get('redirect_mirror_url'));

    Ensembl.cookie.set('redirect_mirror_url');

    var noRedirectURI = function(uri) {
      uri = uri.replace(/(\&|\;)?redirect=[^\&\;]+/, '').replace(/(\&|\;)?debugip=[^\&\;]+/, '').replace(/\?[\;\&]+/, '?').replace(/\?$/, '');
      uri = uri + (uri.match(/\?/) ? ';redirect=no' : '?redirect=no');
      return uri;
    };

    if (redirectCode && redirectCode !== 'no') {
      redirectCode      = redirectCode.split(/\|/);
      if (redirectCode.length >= 2) {
        var currentURI    = noRedirectURI(window.location.href);
        var mirrorName    = redirectCode.shift();
        var remainingTime = parseInt(redirectCode.shift());
        var mirrorURI     = (redirectURI ? noRedirectURI($('<a>').attr('href', redirectURI).prop('href')) : currentURI).replace(window.location.host, mirrorName);
        var messageDiv    = $([
          '<div class="redirect-message hidden">',
          ' <p>You are being redirected to <b><a href="' + mirrorURI + '">', mirrorName, '</a></b> <span class="_redirect_countdown">in ', remainingTime, ' seconds</span>. Click <a class="_redirect_no" href="#">here</a> if you don\'t wish to be redirected.</p>',
          '</div>'
        ].join('')).appendTo($('body').prepend($('<div class="redirect-message-padding hidden"></div>').slideDown())).slideDown().find('a._redirect_no').on('click', function (e) {
          e.preventDefault();
          Ensembl.cookie.set('redirect_mirror', 'no');
          clearInterval(messageDiv.data('countdown'));
          window.location.replace(messageDiv.data('currentURI'));
        }).end().data({
          remainingTime : remainingTime,
          mirrorURI     : mirrorURI,
          currentURI    : currentURI,
          countdown     : setInterval(function() {
            var time  = messageDiv.data('remainingTime') - 1;
            messageDiv.data('remainingTime', time).find('._redirect_countdown').html(time > 0 ? time > 1 ? 'in ' + time + ' seconds' : 'in 1 second' : 'now');
            if (time <= 0) {
              clearInterval(messageDiv.data('countdown'));
              window.location.href = messageDiv.data('mirrorURI');
            }
          }, 1000)
        });
      }
    }
  },

  showCookieMessage: function() {
    var manager = this;
    var cookiesAccepted = Ensembl.cookie.get('cookies_ok');

    if (!cookiesAccepted) {
      $(['<div class="cookie-message hidden">',
        '<p>We use cookies to enhance the usability of our website. If you continue, we\'ll assume that you are happy to receive all cookies.<button>Don\'t show this again</button></p>',
        '<p>Further details about our privacy and cookie policy can be found <a href="/info/about/legal/privacy.html">here</a></p>',
        '</div>'
      ].join(''))
        .prependTo(document.body).slideDown().find('button').on('click', function (e) {
          Ensembl.cookie.set('cookies_ok', 'yes');
          $(this).parents('div').first().slideUp();
          manager.handleMirrorRedirect();
      });
      return true;
    }

    return false;
  },

  showMobileMessage: function() { }

});
