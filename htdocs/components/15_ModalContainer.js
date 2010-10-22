// $Revision$

Ensembl.Panel.ModalContainer = Ensembl.Panel.Overlay.extend({
  constructor: function (id) {
    this.base(id);
    
    Ensembl.EventManager.register('modalOpen', this, this.open);
    Ensembl.EventManager.register('modalClose', this, this.hide);
    Ensembl.EventManager.register('queuePageReload', this, this.setPageReload);
  },
  
  init: function () {
    var panel = this;
    var dims  = this.getDimensions();
    
    this.base(dims.w, dims.h);
    
    this.elLk.content     = $('.modal_content', this.el);
    this.elLk.title       = $('.modal_title', this.el);
    this.elLk.menu        = $('ul.tabs', this.el);
    this.elLk.tabs        = $('li', this.elLk.menu);
    this.elLk.caption     = $('.modal_caption', this.el);
    this.elLk.closeButton = $('.modal_close', this.el);
    
    this.pageReload    = false;
    this.sectionReload = {};
    this.activePanel   = '';
    
    // TODO: check functionality. panel.open() is probably wrong
    $('.modal_confirm', '#' + this.id).live('click', function () {
      var c = confirm(this.title + '\nAre you sure you want to continue?');
      
      this.title = '';
      
      if (c === true) {
        panel.open(this);
      }
      
      return false;
    });
    
    $('.modal_close', '#' + this.id).live('click', function () { panel.hide(); });
    
    // Changing tabs - update configuration and get new content
    $('a', this.elLk.tabs).bind('click', function () {
      var li = $(this).parent();
      
      if (!li.hasClass('active')) {
        Ensembl.EventManager.trigger('updateConfiguration', true);
        
        panel.elLk.tabs.removeClass('active');
        li.addClass('active');
        
        panel.getContent(this.href, this.rel);
      }
      
      li = null;
      return false;
    }); 
  },
  
  setDimensions: function (width, height) {
    this.base(width, height);
    
    if (this.elLk.content) {
      this.elLk.content.height(this.elementHeight - 18);
    }
  },
  
  open: function (el) {
    this.elLk.menu.hide();
    this.elLk.caption.html(el.title || el.innerHTML).show();
    this.elLk.closeButton.attr({ title: 'Close', alt: 'Close' });
    this.show();
    this.getContent(el.href, this.activePanel.match(/config/) && el.rel.match(/config/) ? this.activePanel : el.rel);
    
    return true;
  },
  
  hide: function (escape) {
    this.base();
    
    if ((escape !== true && !Ensembl.EventManager.trigger('updateConfiguration') && (this.pageReload || this.sectionReload.count)) || this.pageReload == 'force') {
      this.setPageReload(false, true);
    }
  },
  
  getContent: function (url, id, failures) {
    id = id || 'modal_default';
    
    var contentEl = this.elLk.content.filter('#' + id);
    var reload    = url.match(/reset=1/) || $('.modal_reload', this.el).remove().length;
    var hash      = (url.match(/#(.+)$/) || [])[1];
    
    this.elLk.content.hide();
    this.activePanel = id;
        
    if (reload) {
      this.elLk.content.empty();
    } else if (id.match(/config/) && contentEl.children(':not(.spinner, .ajax_error)').length) {
      Ensembl.EventManager.triggerSpecific('showConfiguration', id, hash);
      this.changeTab(this.elLk.tabs.children('[rel=' + id + ']').parent());
      this.elLk.closeButton.attr({ title: 'Save and close', alt: 'Save and close' });
      
      return;
    }
    
    contentEl.html('<div class="spinner">Loading Content</div>').show();
    
    $.ajax({
      url: Ensembl.replaceTimestamp(url),
      dataType: 'json',
      context: this,
      success: function (json) {
        var params = hash ? $.extend(json.params || {}, { hash: hash }) : json.params;
        var buttonText, forceReload;
        
        if (json.redirectURL) {
          return this.getContent(json.redirectURL, id);
        }
        
        switch (json.panelType) {
          case 'ModalContent': buttonText = 'Close'; break;
          case 'Configurator': buttonText = 'Save and close'; break;
          default: buttonText = 'Update options'; break;
        }
        
        if (json.activeTab !== null) {
          this.changeTab(this.elLk.tabs.filter('[textContent=' + json.activeTab + ']'));
        }
        
        Ensembl.EventManager.trigger('destroyPanel', id, 'empty'); // clean up handlers, save memory
        
        if (!json.nav) {
          json.wrapper = $(json.wrapper).addClass('no_local_context');
        }
        
        contentEl.html(json.content).wrapInner(json.wrapper).prepend(json.nav);
        
        this.elLk.closeButton.attr({ title: buttonText, alt: buttonText });
        
        forceReload = !!$('.modal_reload', contentEl).length;
        
        if (reload || forceReload) {
          this.setPageReload((url.match(/\bconfig=(\w+)\b/) || [])[1], false, forceReload);
        }
        
        Ensembl.EventManager.trigger('createPanel', id, $((json.content.match(/<input[^<]*class=".*?panel_type.*?".*?>/)||[])[0]).val() || json.panelType, params);
      },
      error: function (e) {
        failures = failures || 1;
        
        if (e.status != 500 && failures < 3) {
          var panel = this;
          setTimeout(function () { panel.getContent(url, id, ++failures); }, 2000);
        } else {
          contentEl.html('<p class="ajax_error">Sorry, the page request timed out.</p>');
        }
      }
    });
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
  
  setPageReload: function (section, reload, force) {
    if (section) {
      this.sectionReload[section] = 1;
      this.sectionReload.count = (this.sectionReload.count || 0) + 1;
    } else if (section !== false) {
      this.pageReload = true;
    }
    
    if (force === true) {
      this.pageReload = 'force';
    }
    
    if (reload === true) {
      Ensembl.EventManager.trigger('reloadPage', !!this.pageReload || this.sectionReload);
      this.sectionReload = {};
    }
  }
});
