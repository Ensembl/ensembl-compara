Ensembl.Panel.Overlay = Ensembl.Panel.extend({
  constructor: function (id) {
    this.base(id);
    
    this.window    = $(window);
    this.isIE6     = $('body').hasClass('ie6');
    this.firstOpen = true;
    
    this.setMinMax();
    
    Ensembl.EventManager.register('windowResize', this, this.pageResize);
  },
  
  init: function () {
    var panel = this;
    
    this.customized = this.getCookie();
    
    this.base();
    
    if (!panel.isIE6) {
      $(this.el).draggable({
        handle: 'div.modal_title',
        stop: function (e, ui) {
          $.extend(panel.customized, ui.position);
          panel.setCookie();
        }
      }).resizable({
        maxWidth:  this.maxWidth,
        maxHeight: this.maxHeight,
        minWidth:  this.minWidth,
        minHeight: this.minHeight,
        stop:      function (e, ui) {
          $.extend(panel.customized, ui.size);
          panel.setCookie();
          
          $(this).css('position', 'fixed').css('top', function (i, top) {
            return parseInt(top, 10) - panel.window.scrollTop();
          });
          
          Ensembl.EventManager.trigger('modalPanelResize');
        }
      });
    }
    
    this.elLk.background = $('#modal_bg').bind('click', function () { panel.hide() });
  },
  
  setCookie: function () {
    var panel  = this;
    var cookie = $.map([ 'width', 'height', 'left', 'top' ], function (i) { return panel.customized[i] || 0; });
    
    Ensembl.cookie.set('modal', cookie.join('|'));
  },
  
  getCookie: function () {
    var cookie = Ensembl.cookie.get('modal').split('|');
    
    return cookie.length === 4 && !this.isIE6 ? {
      width:  Math.min(parseInt(cookie[0], 10), this.maxWidth),
      height: Math.min(parseInt(cookie[1], 10), this.maxHeight),
      left:   parseInt(cookie[2], 10),
      top:    parseInt(cookie[3], 10)
    } : {};
  },
  
  show: function () {
    this.elLk.background.show();
    
    if (this.firstOpen) {
      this.setDimensions();
      this.firstOpen = false;
    }
    
    if (this.isIE6) {
      $('body').css('overflow', 'hidden');
      $('select').hide();
      $('select', this.el).show();
    }
    
    this.base();
  },
  
  hide: function () {
    this.base()
    
    this.elLk.background.hide();
    
    if (this.isIE6) {
      $('body').css('overflow', 'auto');
      $('select').show();
    }
  },
  
  setMinMax: function () {
    this.maxWidth  = Math.round(this.window.width()  * 0.9);
    this.maxHeight = Math.round(this.window.height() * 0.8);
    this.minWidth  = Math.min(700, this.maxWidth);
    this.minHeight = Math.min(500, this.maxHeight);
  },
  
  setDimensions: function () {
    this.setMinMax();
  
    var height       = this.customized.height ? Math.min(this.customized.height, this.maxHeight) : this.maxHeight;
    var width        = this.customized.width  ? Math.min(this.customized.width,  this.maxWidth)  : this.maxWidth;
    var offset       = $(this.el).offset();
    var windowWidth  = this.window.width();
    var windowHeight = this.window.height();

    $(this.el).resizable('option', {
      maxWidth:  this.maxWidth,
      maxHeight: this.maxHeight,
      minWidth:  this.minWidth,
      minHeight: this.minHeight
    }).css({ 
      height: height,
      width:  width,
      top:    !this.customized.top  || offset.top  + height > windowHeight || this.customized.top  + height > windowHeight ? (windowHeight - height) / 2 : this.customized.top,
      left:   !this.customized.left || offset.left + width  > windowWidth  || this.customized.left + width  > windowWidth  ? (windowWidth  - width)  / 2 : this.customized.left
    });
  },
  
  pageResize: function () {
    this.setDimensions();
    
    if (this.visible) {
      Ensembl.EventManager.trigger('modalPanelResize');
    }
  }
});
