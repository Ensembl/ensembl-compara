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

Ensembl.LayoutManager = new Base();

Ensembl.LayoutManager.extend({
  constructor: null,
  
  /**
   * Creates events on elements outside of the domain of panels
   */
  initialize: function () {
    this.id = 'LayoutManager';
    
    Ensembl.EventManager.register('reloadPage',         this, this.reloadPage);
    Ensembl.EventManager.register('validateForms',      this, this.validateForms);
    Ensembl.EventManager.register('makeZMenu',          this, this.makeZMenu);
    Ensembl.EventManager.register('hashChange',         this, this.hashChange);
    Ensembl.EventManager.register('markLocation',       this, this.updateMarkedLocation);
    Ensembl.EventManager.register('toggleContent',      this, this.toggleContent);
    Ensembl.EventManager.register('changeWidth',        this, this.changeWidth);
        
    $('#page_nav .tool_buttons > p').show();
    
    $('#header a:not(#tabs a)').addClass('constant');
    
    if (window.location.hash.match(Ensembl.locationMatch)) {
      $('.ajax_load').val(function (i, val) {
        return Ensembl.urlFromHash(val);
      });
      
      this.hashChange(Ensembl.urlFromHash(window.location.href, true));
    }

    $(document).find('#static').externalLinks();

    $(document).on('click', '.modal_link', function () {
      if (Ensembl.EventManager.trigger('modalOpen', this)) {
        return false;
      }
    }).on('click', '.popup', function () {
      if (window.name.match(/^popup_/)) {
        return true;
      }
      window.open(this.href, '_blank', 'width=950,height=500,resizable,scrollbars');
      return false;
    }).on('click', 'a[rel="external"]', function () { 
      this.target = '_blank';
    }).on('click', 'a.update_panel', function () {
      var panelId     = this.rel;
      var linkedPanel = Ensembl.PanelManager.panels[panelId];

      if (linkedPanel) {
        var params = {};
        if ($(this).find('.update_url').each(function () { params[this.name] = this.value; }).length) {
          Ensembl.updateURL(params);
        }

        params['update_panel'] = 1;

        Ensembl.EventManager.triggerSpecific('updatePanel', panelId, Ensembl.updateURL(params, linkedPanel.params.updateURL));

      } else {
        console.log('Missing panel: ' + panelId);
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

    this.showGDPRCookieBanner();
    this.showTemporaryMessage();
    this.showMirrorMessage();
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

  updateMarkedLocation: function (mr) {
    $('a:not(.constant):not(._location_mark)').filter(function () { // only for the links that have r param
      return this.hostname === window.location.hostname && !!this.href.match(Ensembl.locationMatch);
    }).attr('href', function () {
      return Ensembl.updateURL({mr: mr && mr[0]}, this.href);
    });
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

  showMirrorMessage: function() {
    var redirectedFrom = decodeURIComponent(Ensembl.cookie.get('redirected_from_url'));

    if (redirectedFrom) {
      Ensembl.cookie.set('redirected_from_url', '');

      var paddingDiv,
          messageDiv,
          redirectBackLink = $('<a>').attr('href', redirectedFrom + (redirectedFrom.match(/\?/) ? ';redirect=no' : '?redirect=no'));

      if (redirectBackLink.prop('hostname') != window.location.hostname) { // this will filter any invalid urls

        redirectBackLink.html('Click here to go back to <b>' + redirectBackLink.prop('hostname') + '</b>');
        var messageDiv = $(['<div class="redirect-message hidden">',
                              '<p class="msg">You have been redirected to your nearest mirror. ',
                              '<span class="_redirect_link"></span>',
                            '</p>',
                            '<span class="close">x</span>',
                            '</div>']
                            .join(''))
                            .find('span._redirect_link').append(redirectBackLink).end()
                            .appendTo($('body')).fadeIn();

        messageDiv.find('.close').on('click', { divs: messageDiv }, function(e) {
          e.preventDefault();
          e.data.divs.fadeOut(200);
        });

        paddingDiv = messageDiv = redirectBackLink = null;
      }
    }
  },

  showGDPRCookieBanner: function() {
    var cookie_name = $('#gdpr_cookie_name').val();
    var cookie_for_all_sites = true;
    var cookiesVersion = Ensembl.cookie.get(cookie_name);
    Ensembl.gdpr_version = $('#gdpr_version').val();
    Ensembl.gdpr_policy_url = $('#gdpr_policy_url').val();
    Ensembl.gdpr_terms_url = $('#gdpr_terms_url').val();

    if (Ensembl.gdpr_version && (!cookiesVersion || (cookiesVersion !== Ensembl.gdpr_version))) {
      $([ "<div class='cookie-message'>",
            "<p class='msg'>",
              "This website requires cookies, and the limited processing of your personal data in order to function. By using the site you are agreeing to this as outlined in our ",
              "<a target='_blank' href='",
              Ensembl.gdpr_policy_url,
              "'>Privacy Policy</a>",
              " and <a target='_blank' href='",
              Ensembl.gdpr_terms_url,
              "'> Terms of Use </a>",
            "</p>",
            "<div class='agree-button'>",
              "<a id='gdpr-agree' class='button no-underline'> I Agree </a>",
            "</div>",
          "</div>"
        ].join(''))
        .appendTo(document.body).show().find('#gdpr-agree').on('click', function (e) {
          Ensembl.cookie.set(cookie_name, Ensembl.gdpr_version, '', true, cookie_for_all_sites);
          $(this).addClass('clicked')
                 .closest('.cookie-message').delay(1000).fadeOut(100);
      });
      return true;
    }

    return false;
  },

  showTemporaryMessage: function() {
    var messageSeen = Ensembl.cookie.get('tmp_message_ok');
    var messageDiv  = $('#tmp_message').remove();
    var message     = messageDiv.children('div').text();
    var messageMD5  = messageDiv.children('input[name=md5]').val();
    var messageCol  = messageDiv.children('input[name=colour]').val();
    var expiryHours = parseInt(messageDiv.children('input[name=expiry]').val()) || 24;
    var position    = (messageDiv.children('input[name=position]').val() || '').split(/\s+/);

    if (message && (!messageSeen || messageSeen !== messageMD5)) {
      $(['<div class="tmp-message hidden ' + $.makeArray($.map($.merge([messageCol], position), function(v) { return v ? 'tm-' + v : null; })).join(' ') + '">',
        '<div>' + message + '</div>',
        '<p><button>Close</button></p>',
        '</div>'
      ].join(''))
        .appendTo(document.body).show().find('button').on('click', {
          cookieValue: messageMD5,
          cookieExpiry: new Date(new Date().getTime() + expiryHours * 60 * 60 * 1000).toUTCString()
        }, function (e) {
          e.preventDefault();
          Ensembl.cookie.set('tmp_message_ok', e.data.cookieValue, e.data.cookieExpiry);
          $(this).parents('div').first().fadeOut(200);
      });
      return true;
    }

    return false;
  }

});
