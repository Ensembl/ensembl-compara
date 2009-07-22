// $Revision$

Ensembl.Panel.ModalContainer = Ensembl.Panel.Overlay.extend({
  constructor: function (id) {
    this.base(id);
    
    Ensembl.EventManager.register('modalOpen', this, this.open);
    Ensembl.EventManager.register('modalClose', this, this.close);
    Ensembl.EventManager.register('updateModalTab', this, this.updateTab);
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
    
    $('a', this.elLk.tabs).click(function () {
      var li = $(this).parent();
      
      if (!li.hasClass('active')) {
        myself.elLk.tabs.removeClass('active');
        li.addClass('active');
        
        myself.getContent(this.href);
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
    this.getContent(el.href);
    
    return true;
  },
  
  close: function () {
    this.hide();
    Ensembl.EventManager.trigger('updateConfiguration');
    
    if (this.pageReload) {
      Ensembl.EventManager.trigger('reloadPage');
    }
  },
  
  getContent: function (url, failures) {
    var myself = this;
    
    this.elLk.content.html('<div class="spinner">Loading Content</div>').show();
    
    $.ajax({
      url: url,
      dataType: 'json',
      success: function (json) {
        if (typeof json.activeTab != 'undefined') {
          var tab = myself.elLk.tabs.filter(':eq(' + json.activeTab + ')');
        
          if (!tab.hasClass('active')) {
            myself.elLk.tabs.removeClass('active');
            tab.addClass('active');
          }
          
          myself.elLk.caption.hide();
          myself.elLk.menu.show();
          
          tab = null;
        }
        
        myself.elLk.content.html(json.content).wrapInner(json.wrapper).prepend(json.nav);
        myself.elLk.closeButton.html(json.panelType == 'Configurator' ? 'Save and close' : 'Close');
        
        // TODO: remove once config reseting is working without content being completely regenerated
        if (url.match('reset=1') || $('.modal_reload', this.el).length) {
          Ensembl.EventManager.trigger('queuePageReload');
        }
        
        Ensembl.EventManager.trigger('createPanel', myself.elLk.content.attr('id'), json.panelType);
      },
      error: function (e) {
        failures = failures || 1;
        
        if (e.status != 500 && failures < 3) {
          setTimeout(function () { myself.getContent(url, ++failures); }, 2000);
        } else {
          myself.elLk.content.html('<p class="ajax_error">Failure: The resource failed to load');
        }
      }
    });
  },
  
  setPageReload: function () {
    this.pageReload = true;
  }
});
