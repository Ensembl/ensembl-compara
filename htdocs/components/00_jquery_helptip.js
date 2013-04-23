/**
 * helptip - Displays a helptip on hovering an element. Wrapper around jQuery UI tooltip
 **/
(function ($) {
  $.fn.helptip = function (options) {
    if (typeof options === 'string') {
      return this.tooltip.apply(this, arguments);
    } else {
      options = options || {};
      
      var tip      = options.content;
      var track    = options.track    || $(this).hasClass('_ht_track');
      var position = $.extend({
        my:    track ? 'center top+24' : 'center top+8',
        at:    'center bottom',
        using: function (position, feedback) {
          if (options.track && feedback.vertical === 'bottom') {
            position.top += 16;
          }
          
          $(this).removeClass('helptip-top helptip-bottom helptip-middle').addClass('helptip-' + feedback.vertical).css(position);
        }
      }, options.position || {});
      
      delete options.content;
      delete options.position;
      
      return this.tooltip($.extend({
        track:   track,
        show:    { delay: 100, duration: 1 },
        hide:    false,
        items:   tip ? '*' : undefined,
        position: position,
        content: function () { return (tip || this.title).replace(/\n/g, '<br />'); }
      }, options));
    }
  };
})(jQuery);