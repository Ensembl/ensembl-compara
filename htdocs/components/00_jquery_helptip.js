/**
 * helptip - Displays a helptip on hovering an element
 * Usage:
 * el.helptip('show this on hover', {'static': true}); //create a helptip (or modifies an existing one)
 * el.helptip(''); // hides a helptip
 * el.helptip(false); // completely removes any existing helptip from the element
 **/
(function ($) {
  $.helptip = function (el, tip, options) {
    el      = $(el);
    options = $.extend({
      eventIn: 'mouseenter',
      eventOut: 'mouseleave',
      delay: 100
    }, options);
    
    var container = options.container || $(document.body);
    
    if (typeof tip === 'undefined' || tip === '') {
      tip = el[0].title.replace(/\n/g, '<br />');
      el.removeAttr('title');
    }
    
    var methods = {
      init: function () {
        this.data('helptip').popup = $('<div class="helptip"><div class="ht-inner"></div></div>').appendTo(container);
      },
      
      setTip: function (popup, html) {
        popup.children().html(html);
      },
      
      setOption: function (popup, options) {
        this.data('helptip').options = options;
        
        if (this.data('helptip')['class']) { // previously added class
          popup.removeClass(this.data('helptip')['class']);
        }
        
        if (options['class']) {
          popup.addClass(options['class']);
          this.data('helptip')['class'] = options['class'];
        }
        
        popup.toggleClass('helptip-static', options['static']);
      },
      
      setEventHandlers: function () {
        var handlers = {};
        var func;
        
        if (options.delay) {
          handlers = { over: methods.mouseIn, out: methods.mouseOut, interval: options.delay };
          func     = 'hoverIntent';
          
          this.on('mousemove.helptip-track', function (e) {
            var data = $(this).data('helptip');
            
            if (!data.mousemove) {
              data.coords = { x: e.pageX, y: e.pageY };
            }
          });
        } else {
          handlers[options.eventIn  + '.helptip'] = methods.mouseIn;
          handlers[options.eventOut + '.helptip'] = methods.mouseOut;
          func = 'on';
        }
        
        this[func](handlers).data('helptip').initiated = true;
      },
      
      mouseIn: function (e) {
        var el      = $(this);
        var $window = $(window);
        var popup   = el.data('helptip').popup;
        var options = el.data('helptip').options;
        var pos, originalPos;
        
        if (options['static']) {
          var offset = options.container ? el.position() : el.offset();
          originalPos = pos = { x: offset.left + el.outerWidth() / 2, y: offset.top + el.outerHeight() / 2 };
        } else {
          originalPos = pos = el.data('helptip').coords || { x: e.pageX, y: e.pageY };
          
          el.data('helptip').coords = false;
          
          if (!el.data('helptip').mousemove) {
            el.on('mousemove.helptip', methods.mouseMove).data('helptip').mousemove = true;
          }
        }
        
        popup.removeClass('helptip-left helptip-top');
        
        if ($window.height() < ((pos.y - $window.scrollTop()) * 2)) {
          popup.addClass('helptip-top');
          pos.y -= popup.height();
        }
        
        if ($window.width() < ((pos.x - $window.scrollLeft()) * 2)) {
          popup.addClass('helptip-left');
          pos.x -= (el.data('helptip').offset || {}).width || popup.width();
        }
        
        if (!el.data('helptip').hidden) {
          popup.css({ left: pos.x, top: pos.y }).show();
        }
        
        el.data('helptip').offset = { x: pos.x - originalPos.x, y: pos.y - originalPos.y, width: popup.width() };
        
        el = popup = $window = null;
      },
      
      mouseOut: function () {
        $(this).data('helptip').popup.hide();
        $(this).off('mousemove.helptip').data('helptip').mousemove = false;
      },
      
      mouseMove: function (e) {
        var el = $(this);
        
        if (!el.data('helptip').hidden) {
          var offset = el.data('helptip').offset;
          el.data('helptip').popup.css({ left: offset.x + e.pageX, top: offset.y + e.pageY });
        }
      },
      
      hide: function (popup) {
        this.data('helptip').hidden = true;
        popup.hide();
      },
      
      destroy: function (popup) {
        this.off('.helptip .helptip-track');
        
        if (popup) {
          popup.remove();
        }
        
        this.removeData('helptip');
      }
    };
    
    if (!el.data('helptip')) {
      el.data('helptip', {});
    }
    
    // if helptip already created
    var popup = el.data('helptip').popup;
    
    // destroy any existing helptip instance if first argument is set false
    if (tip === false) {
      methods.destroy.call(el, popup);
      return;
    }
    
    // if not already, instantiate helptip
    if (!popup) {
      methods.init.call(el);
      popup = el.data('helptip').popup;
    } else {
      el.data('helptip').hidden = false;
    }
    
    // set tip
    if (tip) {
      methods.setTip.call(el, popup, tip);
      
      if (options.show) {
        popup.show();
      }
    } else {
      methods.hide.call(el, popup);
    }
    
    // set options
    if (!$.isEmptyObject(options)) {
      methods.setOption.call(el, popup, options);
    }
    
    // set event handlers
    if (!el.data('helptip').initiated) {
      methods.setEventHandlers.call(el);
    }
  };

  $.fn.helptip = function (
    tip,    // text to be displayed on hover
    options // options - static, width (TODO)
  ) {
    if (typeof tip === 'object') {
      options = tip;
      tip     = '';
    }
    
    options = $.extend({ 'static': $(document.body).hasClass('ie6') }, options || {});
    return this.each(function () { $.helptip(this, tip, options); });
  };
})(jQuery);