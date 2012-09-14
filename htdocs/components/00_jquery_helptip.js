/**
 * helptip - Displays a helptip on hovering an element
 **/
(function ($) {
  $.helptip = function (
    el,       // element itself
    tip,      // text to be displayed on hover
    options   // options - delay, width, static (TODO)
  ) {
    el = $(el);
    
    if (typeof tip === 'undefined' || tip === '') {
      tip = el[0].title;
      el.removeAttr('title');
      
      if (!tip) {
        return;
      }
    }
    
    el.on({
      mouseover: function(e) {
        var el      = $(this);
        var helptip = el.data('helptip');
        var pos;
        
        if (options['static']) {
          var offset = el.offset();
              pos    = { x: offset.left + el.outerWidth() / 2, y: offset.top + el.outerHeight() / 2 };
        } else {
          pos = { x: e.pageX, y: e.pageY };
        }
        
        if (!helptip) {
          helptip = $('<div class="helptip"><div class="ht-inner">' + tip + '</div></div>').appendTo(document.body);
          el.data('helptip', helptip);

          if (options['static']) {
            helptip.addClass('helptip-static');
          } else {
            el.on('mousemove', function (e) {
              var el     = $(this);
              var offset = el.data('helptipPos');
              el.data('helptip').css({ left: offset.x + e.pageX, top: offset.y + e.pageY });
            });
          }
        }
        
        helptip.removeClass('helptip-left helptip-top');
        
        if ($(window).height() < ((pos.y - $(window).scrollTop()) * 2)) {
          helptip.addClass('helptip-top');
          pos.y -= helptip.height();
        }
        
        if ($(window).width() < ((pos.x - $(window).scrollLeft()) * 2)) {
          helptip.addClass('helptip-left');
          pos.x -= (el.data('helptipPos') || {}).width || helptip.width();
        }
        
        helptip.css({ left: pos.x, top: pos.y }).show();
        el.data('helptipPos', { x: pos.x - e.pageX, y: pos.y - e.pageY, width: helptip.width() });
      },
      
      mouseout: function () {
        $(this).data('helptip').hide();
      }
    });
  };

  $.fn.helptip = function (tip, options) {
    if (typeof tip === 'object') {
      options = tip;
      tip     = '';
    }
    
    options = $.extend({ 'static': $(document.body).hasClass('ie6') }, options || {});
    return this.each(function () { $.helptip(this, tip, options); });
  };
})(jQuery);