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

Ensembl.Panel.ModalContainer = Ensembl.Panel.Overlay.extend({

  init: function () {
    var panel = this;
    
    this.base();
    
    this.elLk.content        = $('.modal_content',    this.el);
    this.elLk.title          = $('.modal_title',      this.el);
    this.elLk.menu           = $('ul.tabs',           this.el);
    this.elLk.tabs           = $('li',                this.elLk.menu);
    this.elLk.caption        = $('.modal_caption',    this.el);
    this.elLk.closeButton    = $('.modal_close',      this.el).on('click', $.proxy(this.hide, this));
    this.elLk.overlay        = $('.modal_overlay',    this.el);
    this.elLk.overlayBg      = $('.modal_overlay_bg', this.el);
    this.elLk.overlayContent = $('.overlay_content',  this.elLk.overlay);
    
    this.xhr           = false;
    this.reloadURL     = false;
    this.pageReload    = false;
    this.sectionReload = {};
    this.modalReload   = {};
    this.activePanel   = '';
    
    this.el.on('click', '.modal_confirm', function () {
      var c = confirm(this.title + '\nAre you sure you want to continue?');
      
      this.title = '';
      
      if (c === true) {
        panel.open(this);
      }
      
      return false;
    });
    
    $('.overlay_close', this.elLk.overlay).on('click', $.proxy(this.hideOverlay, this));
    
    this.elLk.content.each(function () {
      $(this).data('tab', panel.elLk.tabs.children('a.' + this.id).parent());
    });
    
    this.elLk.tabs.children('a').each(function () {
      $(this).data('panels', panel.elLk.content.filter('#' + this.className).addClass('active'));
    }).on('click', function () { // Changing tabs - update configuration and get new content
      var li = $(this).parent();
      
      if (!li.hasClass('active')) {
        Ensembl.EventManager.trigger('updateConfiguration', true);
        
        if (panel.el) { // updateConfiguration can cause a redirect from MultiSelector, destroying this.el, so check that this hasn't happened before continuing
          panel.elLk.tabs.removeClass('active');
          li.addClass('active');
          
          panel.getContent(this.href, $(this).data('panels').filter('.active').attr('id'));
        }
      }
      
      li = null;
      
      return false;
    });

    Ensembl.EventManager.register('modalOpen',        this, this.open);
    Ensembl.EventManager.register('modalClose',       this, this.hide);
    Ensembl.EventManager.register('modalOverlayShow', this, this.showOverlay);
    Ensembl.EventManager.register('modalOverlayHide', this, this.hideOverlay);
    Ensembl.EventManager.register('modalPanelResize', this, this.resizeOverlay);
    Ensembl.EventManager.register('queuePageReload',  this, this.setPageReload);
    Ensembl.EventManager.register('addModalContent',  this, this.addContent);
    Ensembl.EventManager.register('setActivePanel',   this, function (panelId) { this.activePanel = panelId; this.elLk.content.filter('#' + panelId).addClass('active'); });
    Ensembl.EventManager.register('modalReload',      this, function (panelId) { this.modalReload[panelId] = true; });
  },
  
  open: function (el) {
    var $el     = $(el);
    var caption = (el.className ? ((el.className.match(/\bmodal_title_(\w+)\b/) || []).pop() || '').replace('_', ' ') : '') || this.elLk.caption.html() || el.title || $el.text();
    var rel     = this.el.is(':visible') || $el.hasClass('force') ? el.rel : this.activePanel.match(/config/) && el.rel.match(/config/) ? this.activePanel : el.rel;
        rel     = (rel || '').split('-');
    var tab     = rel[0] ? this.elLk.tabs.children('a.' + rel[0]) : [];
    
    this.elLk.caption.html(caption).show();
    this.elLk.menu.hide();
    this.elLk.closeButton.attr({ title: 'Close', alt: 'Close' });
    this.show();
    this.getContent(el.href || (tab.length ? tab[0].href : ''), rel.join('-'));
    
    tab = null;
    // Add class to stop page scroll on modal open
    $("body").addClass("modal-open");
    return true;
  },
  
  hide: function (escape) {
    this.base();
    
    this.elLk.caption.html('');
    this.hideOverlay();
    
    if ((escape !== true && !Ensembl.EventManager.trigger('updateConfiguration') && (this.pageReload || this.sectionReload.count)) || this.pageReload === 'force') {
      this.setPageReload(false, true);
    } else if ($('.modal_reload', this.el).length) {
      this.setPageReload(false, true, true);
    }
    // Remove class to enable page scroll on modal close
    $("body").removeClass("modal-open");
  },
  
  showOverlay: function (el) {
    this.overlayShown = true;
    
    this.elLk.overlayContent.children().detach().end().append(el);
    this.elLk.overlay.show().css({ marginLeft: -this.elLk.overlay.outerWidth() / 2 });
    
    this.resizeOverlay();
    
    this.elLk.overlayBg.show();
    this.elLk.closeButton.hide();
  },
  
  hideOverlay: function () {
    this.overlayShown = false;
    
    this.elLk.closeButton.show();
    this.elLk.overlayBg.add(this.elLk.overlay).hide();
  },
  
  resizeOverlay: function () {
    if (this.overlayShown) {
      this.elLk.overlayContent.removeClass('overlay_scroll').height('auto');
      
      var panelHeight   = this.el.height();
      var overlayHeight = this.elLk.overlay.outerHeight();
      
      if (this.elLk.overlay.offset().top + overlayHeight > this.el.offset().top + panelHeight) {
        this.elLk.overlayContent.height(panelHeight - this.elLk.overlay.position().top * 2 - (overlayHeight - this.elLk.overlay.height())).addClass('overlay_scroll');
      }
    }
  },
  
  getContent: function (url, id) {
    if (this.xhr) {
      this.xhr.abort();
    }
    
    var reload = url.match(/reset=/)  || $('.modal_reload', this.el).remove().length;
    var hash;
    
    if (id && id.match('-')) {
      hash = id.split('-');
      id   = hash.shift();
      hash = hash.join('-');
    } else {
      hash = (url.match(/#(.+)$/) || [])[1];
    }
    id = id || (hash ? this.activePanel : 'modal_default');
    var contentEl = this.elLk.content.filter('#' + id);
    
    this.elLk.content.hide();
    this.activePanel = id;
    
    if (this.modalReload[id]) {
      delete this.modalReload[id];
      reload = true;
    }
    
    if (reload) {
      contentEl.empty();
      Ensembl.EventManager.trigger('resetConfig');
    } else if (id.match(/config/) && contentEl.children(':not(.spinner, .ajax_error)').length) {
      Ensembl.EventManager.triggerSpecific('showConfiguration', id, hash);
      this.changeTab(this.elLk.content.filter('#' + id).data('tab'));
      this.elLk.closeButton.attr({ title: 'Save and close', alt: 'Save and close' });
      
      return;
    }

    contentEl.html('<div class="spinner">Loading Content</div>').show();

    // To decodeURIComponent for image exports
    var decode = url.match(/decodeURL=1/) || 0

    var params = Ensembl.prepareRequestParams(url, decode);

    this.xhr = $.ajax({
      url: params.requestURL,
      type: params.requestType,
      data: params.requestData,
      dataType: 'json',
      context: this,
      success: function (json) {
        var params = hash ? $.extend(json.params || {}, { hash: hash }) : json.params;
        var wrapper, buttonText, forceReload, nav;
        
        if (json.redirectURL) {
          return this.getContent(json.redirectURL, id);
        }
        
        switch (json.panelType) {
          case 'ModalContent': buttonText = 'Close';          break;
          case 'Configurator': buttonText = 'Save and close'; break;
          default:             buttonText = 'Update options'; break;
        }
        
        if (json.activeTab) {
          this.changeTab(this.elLk.tabs.has('.' + json.activeTab));
        }
        
        Ensembl.EventManager.trigger('destroyPanel', id, 'empty'); // clean up handlers, save memory
        
        wrapper = $(json.wrapper);
        
        if (json.tools) {
          json.nav += json.tools;
        }
        
        if (json.nav) {
          nav = [ '<div class="modal_nav nav">', json.nav, '</div>' ].join('');
        } else {
          wrapper.addClass('no_local_context');
        }
        
        contentEl.html(json.content).wrapInner(wrapper).prepend(nav).find('.tool_buttons > p').show();
        
        this.elLk.closeButton.attr({ title: buttonText, alt: buttonText });
        
        forceReload = $('.modal_reload', contentEl);
        
        if (reload || forceReload.length) {
          this.setPageReload($('input.component', contentEl).val(), false, !!forceReload.length, forceReload.attr('href'));
        }
        
        if (url.match(/reset=/)) {
          params.reset = url.match(/reset=(\w+)/)[1];
        }
        
        Ensembl.EventManager.trigger('createPanel', id, json.panelType || $((json.content.match(/<input[^<]*class="[^<]*panel_type[^<]*"[^<]*>/) || [])[0]).val(), params);
        
        wrapper = nav = forceReload = null;
      },
      error: function (e) {
         if (e.status !== 0) {
          contentEl.html('<div class="error ajax_error"><h3>Ajax error</h3><div class="error-pad"><p>Sorry, the page request failed to load.</p><pre></pre></div></div>').find('pre').text(e.responseText);
        }
      },
      complete: function () {
        this.xhr = false;
      }
    });
  },
  
  addContent: function (el, url, id, tab) {
    tab = this.elLk.tabs.children('a.' + (tab || id));
    
    if (el) {
      this.elLk.content.filter(':last').after(el);
      this.elLk.content = $('.modal_content', this.el);
      
      tab.data('panels').push(el[0]);
      el.data('tab', tab.parent());
    }
    
    this.getContent(url, id);
    
    tab = null;
  },
  
  changeTab: function (tab) {
    if (!tab.hasClass('active')) {
      this.elLk.tabs.removeClass('active');
      tab.addClass('active');
    }
    
    this.elLk.caption.hide();
    this.elLk.menu.show();
    
    tab = null;
  },
  
  setPageReload: function (section, reload, force, url) {
    if (section && Ensembl.PanelManager.panels[section]) {
      this.sectionReload[section] = 1;
      this.sectionReload.count = (this.sectionReload.count || 0) + 1;
    } else if (section !== false) {
      this.pageReload = true;
    }
    
    if (force === true) {
      this.pageReload = 'force';
    }
    
    if (url) {
      this.reloadURL = url;
    }
    
    if (reload === true) {
      Ensembl.EventManager.trigger('reloadPage', !!this.pageReload || this.sectionReload, this.reloadURL);
      Ensembl.EventManager.trigger('partialReload');
      this.sectionReload = {};
    }
  }
});
