/*
 * Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
      
      return this.map(function () {
        return $(this).data('uiTooltip') ? this : $(this).tooltip($.extend({
          track:   track,
          show:    { delay: 100, duration: 1 },
          hide:    false,
          items:   tip ? '*' : undefined,
          position: position,
          content: function () { return (tip || this.title).replace(/\n/g, '<br />'); }
        }, options))[0];
      });
    }
  };
})(jQuery);