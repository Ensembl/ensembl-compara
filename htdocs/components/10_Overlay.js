// $Revision$

Ensembl.Panel.Overlay = Ensembl.Panel.extend({
  constructor: function (id) {
    var panel = this;
    
    this.base(id);
    this.window = $(window);
    this.storeWindowDimensions();
    
    this.constant   = { isOldIE: $(document.body).hasClass('ie67'), minWidth: 800, minHeight: 600, padding: 100, minPad: 25, borderWidth: 7, zIndex: 999999999, titleHeight: 20, closeIconHeight: 22, minCustomWidth: 700, minCustomHeight: 400, keepAspect: false };
    this.customized = false;
    this.dragProps  = {};
    this.background = $('#modal_bg').css({ opacity: 0.2 })
    .click(function () {
      panel.hide();
    });
    this.border = $('#modal_border').css({ opacity: 0.5 })
    .mousemove(function (event) {
      if (panel.isResizable) return;
      var pos = $(this).offset();
      var direction = '';
      if (event.pageY <= pos.top + panel.constant.borderWidth) {
        direction += 'n';
      } else if (event.pageY >= pos.top + panel.elementHeight + panel.constant.borderWidth) {
        direction += 's';
      }
      if (event.pageX <= pos.left + panel.constant.borderWidth) {
        direction += 'w';
      } else if (event.pageX >= pos.left + panel.elementWidth + panel.constant.borderWidth) {
        direction += 'e';
      }
      this.style.cursor = direction + '-resize';
      panel.dragProps.direction = direction;
    })
    .mousedown(function (event) {
      panel.isResizable = true;
      panel.dragProps = {x: event.pageX, y: event.pageY, height: panel.elementHeight, width: panel.elementWidth, aspectRatio: panel.aspectRatio, direction: panel.dragProps.direction};
      return false;
    });
    
    var eventTarget = this.constant.isOldIE ? $(document.body) : this.window;
    
    eventTarget.bind('mousemove', function (event) {
      if (panel.isResizable) {
        panel.resize(event);
        return false;
      }
    });
    eventTarget.bind('mouseup', function () {
      if (panel.visible) {
        panel.isResizable = false;
        panel.dragProps = {};
      }
    });
    if (this.constant.isOldIE) {
      this.window.bind('scroll', function () {
        if (panel.visible) panel.setDimensions();
      });
    }

    if (!this.constant.isOldIE) $('.modal_close', this.el).css({top: this.constant.closeIconHeight / -2 - this.constant.borderWidth, right: this.constant.closeIconHeight / -2 - this.constant.borderWidth});
    Ensembl.EventManager.register('windowResize', this, this.pageResize);
  },
  
  init: function (width, height) {
    this.base();
    this.setDimensions(width, height);
  },
  
  show: function (width, height) {
    this.storeWindowDimensions();
    this.base();
    this.setDimensions(width, height);
    this.background .show().css({zIndex: this.constant.zIndex - 2});
    this.border     .show().css({zIndex: this.constant.zIndex - 1});
    $(this.el)      .show().css({zIndex: this.constant.zIndex});
    
    if (this.constant.isOldIE) {
      $('select').hide();
      $('select', this.el).show();
    }
    this.visible = true;
  },
  
  hide: function () {
    this.base();
    this.background.hide();
    this.border.hide();
    $(this.el).hide();

    if (this.constant.isOldIE) {
      $('select').show();
    }
    this.visible = false;
  },
  
  resize: function (event) {
    var d = this.dragProps.direction || '';
    var drag = {
      x: d.match(/e|w/) ? (-1 * !!d.match('w') || 1) * (event.pageX - this.dragProps.x) : 0,
      y: d.match(/n|s/) ? (-1 * !!d.match('n') || 1) * (event.pageY - this.dragProps.y) : 0
    };
    if (this.keepAspect) {
      if (drag.x > this.dragProps.aspectRatio * drag.y) {
        drag.x = drag.y * this.dragProps.aspectRatio;
      } else {
        drag.y = drag.x / this.dragProps.aspectRatio;
      }
    }
    var maxDims = this.getMaxDimensions();
    this.customized = {
      w: Math.max(Math.min(this.dragProps.width + drag.x * 2, maxDims.w), this.constant.minCustomWidth),
      h: Math.max(Math.min(this.dragProps.height + drag.y * 2, maxDims.h), this.constant.minCustomHeight)
    };
    this.setDimensions(this.customized.w, this.customized.h);
    Ensembl.EventManager.trigger('modalPanelResize');
  },
  
  getMaxDimensions: function() {
    return {
      w: this.windowWidth  - this.constant.borderWidth * 2 - this.constant.closeIconHeight,
      h: this.windowHeight - this.constant.borderWidth * 2 - this.constant.closeIconHeight
    }
  },
  
  getDimensions: function () {
    var width  = this.customized ? this.customized.w : this.windowWidth  - this.constant.padding * 2;
    var height = this.customized ? this.customized.h : this.windowHeight - this.constant.padding * 2;
    
    if (this.customized) {
      var maxDims = this.getMaxDimensions();
      if (width  > maxDims.w) width  = maxDims.w;
      if (height > maxDims.h) height = maxDims.h;
    } else {
      if (width  < this.constant.minWidth)  width  = Math.min(this.constant.minWidth,  this.windowWidth  - this.constant.minPad * 2);
      if (height < this.constant.minHeight) height = Math.min(this.constant.minHeight, this.windowHeight - this.constant.minPad * 2);
    }

    return { w: width, h: height };
  },
  
  setDimensions: function (width, height) {
    this.elementWidth  = width  || this.elementWidth  || $(this.el).width();
    this.elementHeight = height || this.elementHeight || $(this.el).height();
    
    var fix = this.constant.isOldIE ? {top: this.window.scrollTop(), left: this.window.scrollLeft()} : {top: 0, left: 0};
    $(this.el).css({
      height:     this.elementHeight,
      width:      this.elementWidth,
      marginTop:  this.elementHeight / -2 + fix.top,
      marginLeft: this.elementWidth  / -2 + fix.left
    });
    this.border.css({
      height:     this.elementHeight + this.constant.borderWidth * 2,
      width:      this.elementWidth  + this.constant.borderWidth * 2,
      marginTop:  this.elementHeight / -2 - this.constant.borderWidth + fix.top,
      marginLeft: this.elementWidth  / -2 - this.constant.borderWidth + fix.left
    });
    if (this.constant.isOldIE) {
      this.background.css({
        marginTop:  fix.top,
        marginLeft: fix.left,
        height:     this.windowHeight,
        width:      this.windowWidth
      });
    }
    this.aspectRatio = this.elementWidth / this.elementHeight;
  },

  storeWindowDimensions: function () {
    this.windowHeight = this.window.height();
    this.windowWidth  = this.window.width();
  },
  
  pageResize: function () {
    this.storeWindowDimensions();
    var dims = this.getDimensions();
    this.setDimensions(dims.w, dims.h);
    if (this.visible) {
      Ensembl.EventManager.trigger('modalPanelResize');
    }
  }
});
