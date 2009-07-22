// $Revision$

Ensembl.Panel.Overlay = Ensembl.Panel.extend({
  constructor: function (id) {
    var myself = this;
    
    this.base(id);
    this.storeWindowDimensions();
    
    this.dimensions = { minWidth: 800, minHeight: 600, padding: 200, minPad: 50 }; // padding goes half on either side (ie 100/100);
    this.background = $('#modal_bg');

    this.background.css({ display: 'none', opacity: 0.25 }).click(function(){
      myself.hide();
    });
    
    $(window).resize(function () {
      myself.pageResize();
    }).scroll(function () {
      if (myself.visible) {
        myself.setPosition();
      }
    });
  },
  
  init: function (width, height) {
    this.base();
    this.setDimensions(width, height);
  },
  
  show: function (width, height) {
    this.storeWindowDimensions();
    this.base();
    this.setDimensions(width, height);
    this.setPosition();
    this.setBackground();
  },
  
  hide: function () {
    this.base();
    this.removeBackground();
    
    $(this.el).hide();
  },
  
  getDimensions: function () {
    var width  = this.windowWidth  - this.dimensions.padding;
    var height = this.windowHeight - this.dimensions.padding;
    
    if (width < this.dimensions.minWidth) {
      width = [ this.dimensions.minWidth, this.windowWidth - this.dimensions.minPad ].sort(function (a, b) { return a - b })[0];
    }
    
    if (height < this.dimensions.minHeight) {
      height = [ this.dimensions.minHeight, this.windowHeight - this.dimensions.minPad ].sort(function (a, b) { return a - b })[0];
    }
    
    return { w: width, h: height };
  },
  
  setDimensions: function (width, height) {
    this.elementWidth  = width  || this.elementWidth  || $(this.el).width();
    this.elementHeight = height || this.elementHeight || $(this.el).height();
    
    $(this.el).css({ height: this.elementHeight, width: this.elementWidth });
  },
  
  setPosition: function () {    
    var top  = $(window).scrollTop()  + ((this.windowHeight - this.elementHeight) / 2);
    var left = $(window).scrollLeft() + ((this.windowWidth  - this.elementWidth)  / 2);
    
    if (this.scrollHeight < top + this.elementHeight) {
      top = this.scrollHeight - this.elementHeight - (this.dimensions.minPad / 2);
    }
    
    if (this.scrollWidth < left + this.elementWidth) {
      left = this.scrollWidth - this.elementWidth - (this.dimensions.minPad / 2);
    }
    
    $(this.el).css({ position: 'absolute', top: top, left: left, zIndex: 999999999 });
  },
  
  /**
   * This sets the background overlays width and height and decides if we should
   * be hiding the selects on the page
   */
  setBackground: function () {
    var width, height;
    
    // hide all selects if we are IE and can not handle selects properly
    if ($.browser.msie) {
      $('select').hide();
    }
    
    // show overlay on screen
    this.background.css({
      width:  [ this.scrollWidth,  this.windowWidth  ].sort(function (a, b) { return b - a })[0], 
      height: [ this.scrollHeight, this.windowHeight ].sort(function (a, b) { return b - a })[0]
    }).show();
  },
  
  /**
   * This hides the background overlay and decides if we should show selects on
   * the page.
   */
  removeBackground: function () {
    // hide all selects if we are IE and can not handle selects properly
    if ($.browser.msie) {
      $('select').show();
    }
    
    this.background.hide();
  },
  
  storeWindowDimensions: function () {
    this.windowWidth  = $(window).width();
    this.windowHeight = $(window).height();
    
    if (typeof window.scrollMaxX != 'undefined') {
      this.scrollWidth  = this.windowWidth  + window.scrollMaxX;  
      this.scrollHeight = this.windowHeight + window.scrollMaxY;
    } else {
      this.scrollWidth  = [ this.windowWidth,  document.body.scrollWidth,  document.body.offsetWidth  ].sort(function (a, b) { return b - a })[0];
      this.scrollHeight = [ this.windowHeight, document.body.scrollHeight, document.body.offsetHeight ].sort(function (a, b) { return b - a })[0];
    }
  },
  
  pageResize: function () {
    this.storeWindowDimensions();
    
    var dims = this.getDimensions();
      
    this.setDimensions(dims.w, dims.h);
    
    if (this.visible) {
      this.setPosition();
      this.setBackground();
    }
  }
});
