// $Revision$

Ensembl.Panel.Overlay = Ensembl.Panel.extend({
  constructor: function (id) {
    this.base(id);
    this.window = $(window);
    this.storeWindowDimensions();
    
    this.constant = {
      isIE6: $('body').hasClass('ie6'),
      minWidth: 800,
      minHeight: 600,
      padding: 100,
      minPad: 25,
      borderWidth: 7,
      titleHeight: 20,
      closeIconHeight: 22
    };
    
    this.customized = false;
    this.dragProps  = {};
    
    Ensembl.EventManager.register('windowResize', this, this.pageResize);
    Ensembl.EventManager.register('mouseUp', this, this.mouseup);
  },
  
  init: function (width, height) {
    var panel = this;
    
    this.base();
    
    this.elLk.background = $('#modal_bg').css('opacity', 0.2).bind('click', function () { panel.hide(); });
    
    if ($('body').hasClass('ie')) {
      this.elLk.background.bind('mouseout', function (e) { 
        if (!e.relatedTarget) {
          panel.mouseup();
        }
      });
    }
    
    this.elLk.border = $('#modal_border').css('opacity', 0.5).bind({
      mousemove: function (e) {
        if (panel.isResizable) {
          return;
        }
        
        var pos = $(this).offset();
        var direction = '';
        
        if (e.pageY <= pos.top + panel.constant.borderWidth) {
          direction += 'n';
        } else if (e.pageY >= pos.top + panel.elementHeight + panel.constant.borderWidth) {
          direction += 's';
        }
        
        if (e.pageX <= pos.left + panel.constant.borderWidth) {
          direction += 'w';
        } else if (e.pageX >= pos.left + panel.elementWidth + panel.constant.borderWidth) {
          direction += 'e';
        }
        
        this.style.cursor = direction + '-resize';
        panel.dragProps.direction = direction;
      },
      mousedown: function (e) {
        var pad = panel.constant.borderWidth + panel.constant.minPad * 2;
        
        panel.isResizable = panel.constant.minWidth + pad < panel.window.width() && panel.constant.minHeight + pad < panel.window.height();
        
        if (panel.isResizable) {
          panel.mousemove = function (e) {
            panel.resize(e);
            return false;
          };
          
          $(document).bind('mousemove', panel.mousemove);        
          
          panel.dragProps = {
            x: e.pageX, 
            y: e.pageY, 
            height: panel.elementHeight, 
            width: panel.elementWidth, 
            aspectRatio: panel.aspectRatio, 
            direction: panel.dragProps.direction
          };
        }
        
        return false;
      }
    });
    
    this.setDimensions(width, height);
    
    if (this.constant.isIE6) {
      this.window.bind('scroll', function () {
        if (panel.visible) {
          panel.setDimensions();
        }
      });
    }
  },
  
  show: function (width, height) {
    this.storeWindowDimensions();
    this.base();
    this.setDimensions(width, height);
    this.elLk.background.show();
    this.elLk.border.show();
    
    if (this.constant.isIE6) {
      $('select').hide();
      $('select', this.el).show();
    }
    
    this.visible = true;
  },
  
  hide: function () {
    this.base();
    this.elLk.background.hide();
    this.elLk.border.hide();

    if (this.constant.isIE6) {
      $('select').show();
    }
    
    this.visible = false;
  },
  
  mouseup: function () {
    $(document).unbind('mousemove', this.mousemove);
    
    this.isResizable = false;
    this.dragProps = {};
    
    this.setDimensions(this.customized.w, this.customized.h);
    
    Ensembl.EventManager.trigger('modalPanelResize');
  },
  
  resize: function (e) {
    var maxDims = this.getMaxDimensions();
    var d = this.dragProps.direction || '';
    var drag = {
      x: d.match(/e|w/) ? (-1 * !!d.match('w') || 1) * (e.pageX - this.dragProps.x) : 0,
      y: d.match(/n|s/) ? (-1 * !!d.match('n') || 1) * (e.pageY - this.dragProps.y) : 0
    };
    
    this.customized = {
      w: Math.max(Math.min(this.dragProps.width + drag.x * 2, maxDims.w), this.constant.minWidth),
      h: Math.max(Math.min(this.dragProps.height + drag.y * 2, maxDims.h), this.constant.minHeight)
    };
    
    this.setDimensions(this.customized.w, this.customized.h);
  },
  
  getMaxDimensions: function () {
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
    var fix = this.constant.isIE6 ? { top: this.window.scrollTop(), left: this.window.scrollLeft() } : { top: 0, left: 0 };
    
    this.elementWidth  = width  || this.elementWidth  || $(this.el).width();
    this.elementHeight = height || this.elementHeight || $(this.el).height();
    
    $(this.el).css({
      height:     this.elementHeight,
      width:      this.elementWidth,
      marginTop:  this.elementHeight / -2 + fix.top,
      marginLeft: this.elementWidth  / -2 + fix.left
    });
    
    this.elLk.border.css({
      height:     this.elementHeight + this.constant.borderWidth * 2,
      width:      this.elementWidth  + this.constant.borderWidth * 2,
      marginTop:  this.elementHeight / -2 - this.constant.borderWidth + fix.top,
      marginLeft: this.elementWidth  / -2 - this.constant.borderWidth + fix.left
    });
    
    if (this.constant.isIE6) {
      this.elLk.background.css({
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
