// $Revision$

Ensembl.Panel.ModalContainer = Ensembl.Panel.Overlay.extend({
  constructor: function (id) {
    this.base(id);
    
    Ensembl.EventManager.register('modalOpen', this, this.open);
    Ensembl.EventManager.register('modalClose', this, this.close);
    Ensembl.EventManager.register('queuePageReload', this, this.setPageReload);
  },
  
  init: function () {
    if (Ensembl.ajax != 'enabled') {
      return;
    }
    
    var myself = this;
    var dims = this.getDimensions();    
    
    this.base(dims.w, dims.h);
    
    this.elLk.content = $('.modal_content', this.el);
    this.elLk.title = $('.modal_title', this.el);
    this.elLk.menu = $('ul.tabs', this.el);
    this.elLk.tabs = $('li', this.elLk.menu);
    this.elLk.caption = $('.modal_caption', this.el);
    this.elLk.closeButton = $('.modal_close', this.el);
    
    this.pageReload = false;
    this.sectionReload = {};
    this.activePanel = '';
    
    // TODO: check functionality. myself.open() is probably wrong
    $('.modal_confirm', '#' + this.id).live('click', function () {
      var c = confirm(this.title + '\nAre you sure you want to continue?');
      
      this.title = '';
      
      if (c === true) {
        myself.open(this);
      }
      
      return false;
    });
    
    $('.modal_close', '#' + this.id).live('click', function () { myself.close(); });
    
    // Changing tabs - update configuration and get new content
    $('a', this.elLk.tabs).click(function () {
      var li = $(this).parent();
      
      if (!li.hasClass('active')) {
        Ensembl.EventManager.trigger('updateConfiguration', true);
        
        myself.elLk.tabs.removeClass('active');
        li.addClass('active');
        
        myself.getContent(this.href, this.rel);
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
    this.show();
    this.getContent(el.href, this.activePanel.match(/config/) && el.rel.match(/config/) ? this.activePanel : el.rel);
    
    return true;
  },
  
  close: function () {
    this.hide();
    
    if (!Ensembl.EventManager.trigger('updateConfiguration') && (this.pageReload || this.sectionReload.count)) {
      this.setPageReload(false, true);
    }
  },
  
  getContent: function (url, id, failures) {
    var myself = this;
    
    id = id || 'modal_default';
    
    var contentEl = this.elLk.content.filter('#' + id);
    var reload = url.match('reset=1') || $('.modal_reload', this.el).length;
    
    this.elLk.content.hide();
    this.activePanel = id;
    
    if (!reload && id.match(/config/) && contentEl.children().length) {
      Ensembl.EventManager.triggerSpecific('showConfiguration', id);
      this.changeTab(this.elLk.tabs.children().filter('[rel=' + id + ']').parent());
      this.elLk.closeButton.html('Save and close');
      
      return;
    }
    
    contentEl.html('<div class="spinner">Loading Content</div>').show();
    
    $.ajax({
      url: url,
      dataType: 'json',
      success: function (json) {
        if (typeof json.activeTab != 'undefined') {
          myself.changeTab(myself.elLk.tabs.filter(':eq(' + json.activeTab + ')'));
        }
        
        Ensembl.EventManager.trigger('destroyPanel', id, true); // clean up handlers, save memory
        
        contentEl.html(json.content).wrapInner(json.wrapper).prepend(json.nav);
        
        myself.elLk.closeButton.html(json.panelType == 'Configurator' ? 'Save and close' : 'Close');
        
        // TODO: remove once config reseting is working without content being completely regenerated
        if (reload) {
          myself.setPageReload((url.match(/\bconfig=(\w+)\b/) || [])[1]);
        }
        
        Ensembl.EventManager.trigger('createPanel', id, json.panelType);
      },
      error: function (e) {
        failures = failures || 1;
        
        if (e.status != 500 && failures < 3) {
          setTimeout(function () { myself.getContent(url, id, ++failures); }, 2000);
        } else {
          contentEl.html('<p class="ajax_error">Failure: The resource failed to load</p>');
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
  
  setPageReload: function (section, reload) {
    if (section) {
      this.sectionReload[section] = 1;
      this.sectionReload.count = (this.sectionReload.count || 0) + 1;
    } else if (section !== false) {
      this.pageReload = true;
    }
    
    if (reload === true) {
      Ensembl.EventManager.trigger('reloadPage', this.pageReload || this.sectionReload);
      this.sectionReload = {};
    }
  }
});
