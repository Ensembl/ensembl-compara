// $Revision$

Ensembl.Panel.ModalContainer = Ensembl.Panel.Overlay.extend({
  constructor: function (id) {
    this.base(id);
    
    Ensembl.EventManager.register('modalOpen',       this, this.open);
    Ensembl.EventManager.register('modalClose',      this, this.hide);
    Ensembl.EventManager.register('queuePageReload', this, this.setPageReload);
    Ensembl.EventManager.register('addModalContent', this, this.addContent);
    Ensembl.EventManager.register('setActivePanel',  this, function (panelId) { this.activePanel = panelId;       });
    Ensembl.EventManager.register('modalReload',     this, function (panelId) { this.modalReload[panelId] = true; });
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    this.elLk.content     = $('.modal_content', this.el);
    this.elLk.title       = $('.modal_title', this.el);
    this.elLk.menu        = $('ul.tabs', this.el);
    this.elLk.tabs        = $('li', this.elLk.menu);
    this.elLk.caption     = $('.modal_caption', this.el);
    this.elLk.closeButton = $('.modal_close', this.el);
    
    this.xhr           = false;
    this.reloadURL     = false;
    this.pageReload    = false;
    this.sectionReload = {};
    this.modalReload   = {};
    this.activePanel   = '';
    
    this.live.push(
      $('.modal_confirm', this.el).live('click', function () {
        var c = confirm(this.title + '\nAre you sure you want to continue?');
        
        this.title = '';
        
        if (c === true) {
          panel.open(this);
        }
        
        return false;
      }),
      
      $('.modal_close', this.el).live('click', function () {
        panel.hide();
      })
    );
    
    this.elLk.content.each(function () {
      $(this).data('tab', panel.elLk.tabs.children('a.' + this.id).parent());
    });
    
    this.elLk.tabs.children('a').each(function () {
      $(this).data('panels', panel.elLk.content.filter('#' + this.className).addClass('active'));
    }).bind('click', function () { // Changing tabs - update configuration and get new content
      var li = $(this).parent();
      
      if (!li.hasClass('active')) {
        Ensembl.EventManager.trigger('updateConfiguration', true);
        
        panel.elLk.tabs.removeClass('active');
        li.addClass('active');
        
        panel.getContent(this.href, $(this).data('panels').filter('.active').attr('id'));
      }
      
      li = null;
      
      return false;
    });
  },
  
  open: function (el) {
    var caption = /modal_title_([^\s]+)/.exec(el.className + ' ');
    var rel     = this.el.is(':visible') ? el.rel : this.activePanel.match(/config/) && el.rel.match(/config/) ? this.activePanel : el.rel;
    var tab     = rel ? this.elLk.tabs.children('a.' + rel) : [];
    
    if (tab.length) {
      rel = tab.data('panels').filter('.active').attr('id');
    }
    
    this.elLk.caption.html(caption ? caption[1].replace('_', ' ') : this.elLk.caption.html() || el.title || el.innerHTML).show();
    this.elLk.menu.hide();
    this.elLk.closeButton.attr({ title: 'Close', alt: 'Close' });
    this.show();
    this.getContent(el.href, rel);
    
    tab = null;
    
    return true;
  },
  
  hide: function (escape) {
    this.base();
    
    this.elLk.caption.html('');
    
    Ensembl.EventManager.trigger('modalHide');
    
    if ((escape !== true && !Ensembl.EventManager.trigger('updateConfiguration') && (this.pageReload || this.sectionReload.count)) || this.pageReload === 'force') {
      this.setPageReload(false, true);
    }
  },
  
  getContent: function (url, id) {
    if (this.xhr) {
      this.xhr.abort();
    }
    
    var reload = url.match(/reset=/)  || $('.modal_reload', this.el).remove().length;
    var hash   = (url.match(/#(.+)$/) || [])[1];
    
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
    } else if (id.match(/config/) && contentEl.children(':not(.spinner, .ajax_error)').length) {
      Ensembl.EventManager.triggerSpecific('showConfiguration', id, hash);
      this.changeTab(this.elLk.content.filter('#' + id).data('tab'));
      this.elLk.closeButton.attr({ title: 'Save and close', alt: 'Save and close' });
      
      return;
    }
    
    contentEl.html('<div class="spinner">Loading Content</div>').show();
    
    this.xhr = $.ajax({
      url: Ensembl.replaceTimestamp(url),
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
          contentEl.html('<p class="ajax_error">Sorry, the page request failed to load.</p>');
        }
      },
      complete: function () {
        this.xhr = false;
      }
    });
  },
  
  addContent: function (el, url, id, tab) {
    tab = this.elLk.tabs.children('a.' + (tab || id));
    
    this.elLk.content.filter(':last').after(el);
    this.elLk.content = $('.modal_content', this.el);
    
    tab.data('panels').push(el[0]);
    el.data('tab', tab.parent());
    
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
      this.sectionReload = {};
    }
  }
});
