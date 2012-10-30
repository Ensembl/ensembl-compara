/**
 * helptip - Displays a helptip on hovering an element
 * Usage:
 * el.helptip('show this on hover', {'static': true}); //create a helptip (or modifies an existing one)
 * el.helptip(''); // hides a helptip
 * el.helptip(false); // completely removes any existing helptip from the element
 **/
(function ($) {
  $.helptip = function (el, tip, options) {
    el = $(el);
    
    if (typeof tip === 'undefined' || tip === '') {
      tip = el[0].title;
      el.removeAttr('title');
    }
    
    var methods = {
      init: function() {
        this.data('helptip').popup = $('<div class="helptip"><div class="ht-inner"></div></div>').appendTo(document.body);
      },
      
      setTip: function(popup, html) {
        popup.children().html(html);
      },
      
      setOption: function(popup, options) {
        this.data('helptip').options = options;
        if (this.data('helptip')['class']) { //previously added class
          popup.removeClass(this.data('helptip')['class']);
        }
        if (options['class']) {
          popup.addClass(options['class']);
          this.data('helptip')['class'] = options['class'];
        }
        popup.toggleClass('helptip-static', options['static']);
      },
      
      setEventHandlers: function() {
        this.on({
          'mouseover.helptip': function(e) {
            var el      = $(this);
            var popup   = el.data('helptip').popup;
            var options = el.data('helptip').options;
            var pos;
            
            if (options['static']) {
              var offset = el.offset();
                  pos    = { x: offset.left + el.outerWidth() / 2, y: offset.top + el.outerHeight() / 2 };
            } else {
              pos = { x: e.pageX, y: e.pageY };
              
              if (!el.data('helptip').mousemove) {
                el.on('mousemove.helptip', function (e) {
                  var el = $(this);
                  if (!el.data('helptip').hidden) {
                    var offset = el.data('helptip').offset;
                    el.data('helptip').popup.css({ left: offset.x + e.pageX, top: offset.y + e.pageY }).show();
                  }
                });
                el.data('helptip').mousemove = true;
              }
            }
            
            popup.removeClass('helptip-left helptip-top');
            
            if ($(window).height() < ((pos.y - $(window).scrollTop()) * 2)) {
              popup.addClass('helptip-top');
              pos.y -= popup.height();
            }
            
            if ($(window).width() < ((pos.x - $(window).scrollLeft()) * 2)) {
              popup.addClass('helptip-left');
              pos.x -= (el.data('helptip').offset || {}).width || popup.width();
            }
            if (!el.data('helptip').hidden) {
              popup.css({ left: pos.x, top: pos.y }).show();
            }
            el.data('helptip').offset = { x: pos.x - e.pageX, y: pos.y - e.pageY, width: popup.width() };
          },
          
          'mouseout.helptip': function () {
            $(this).data('helptip').popup.hide();
          }
        }).data('helptip').initiated = true;
      },
      
      hide: function (popup) {
        this.data('helptip').hidden = true;
        popup.hide()
      },
      
      destroy: function (popup) {
        this.off('.helptip');
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
      methods.destroy.apply(el, [popup]);
      return;
    }
    
    // if not already, instantiate helptip
    if (!popup) {
      methods.init.apply(el);
      popup = el.data('helptip').popup;
    } else {
      el.data('helptip').hidden = false;
    }
    
    // set tip
    if (tip) {
      methods.setTip.apply(el, [popup, tip]);
    } else {
      methods.hide.apply(el, [popup]);
    }
    
    // set options
    if (!$.isEmptyObject(options)) {
      methods.setOption.apply(el, [popup, options]);
    }
    
    // set event handlers
    if (!el.data('helptip').initiated) {
      methods.setEventHandlers.apply(el);
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