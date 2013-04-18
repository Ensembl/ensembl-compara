/**
 * helptip - Displays a helptip on hovering an element
 * Usage:
 * el.helptip('show this on hover', [OPTIONS]); // create a helptip (or modifies an existing one)
 * el.helptip(false);                           // completely removes any existing helptip from the element
 **/
(function ($) {
  $.fn.helptip = function (
    tip,    // text to be displayed on hover
    options // options - static, width (TODO)
  ) {
    if (typeof tip === 'object') {
      options = tip;
      tip     = undefined;
    }
    
    options = $.extend({
      track:   $(this).hasClass('_ht_track'),
      show:    { delay: 100, duration: 1 },
      hide:    false,
      items:   tip ? '*' : undefined,
      content: function () { return (tip || this.title).replace(/\n/g, '<br />'); }
    }, options || {});
    
    options.position = {
      my:    options.track ? 'center top+24' : 'center top+8',
      at:    'center bottom',
      using: function (position, feedback) {
        if (options.track && feedback.vertical === 'bottom') {
          position.top += 16;
        }
        
        $(this).removeClass('helptip-top helptip-bottom helptip-middle').addClass('helptip-' + feedback.vertical).css(position);
      }
    };
    
    return tip === false ? this.tooltip('destroy') : this.tooltip(options);
  };
})(jQuery);