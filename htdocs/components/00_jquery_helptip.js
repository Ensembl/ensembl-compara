/*
 * Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

      return this.map(function () {

        var $this = $(this);
        var opts  = $.extend({}, options || {});

        if ($this.data('uiTooltip')) {
          return this;
        }

        opts.content  = opts.content  || this.title.replace(/\n/g, '<br />') || $this.find('>._ht_tip').first().remove().text();
        opts.track    = opts.track    || $this.hasClass('_ht_track');
        opts.delay    = opts.delay    || $this.hasClass('_ht_delay') || $('<div>').html(opts.content).find('a[href]').length;
        opts.position = $.extend({
          my:    opts.track ? 'center top+24' : 'center top+8',
          at:    'center bottom',
          using: function (position, feedback) {
            if (opts.track && feedback.vertical === 'bottom') {
              position.top += 16;
            }

            $(this).removeClass('helptip-top helptip-bottom helptip-middle').addClass('helptip-' + feedback.vertical).css(position);
          }
        }, opts.position || {});

        if (opts.delay) {
          opts.close = function(e, ui) {
            ui.tooltip.on({
              'mouseenter.helptip': function() {
                $(this).clearQueue();
              },
              'mouseleave.helptip': function() {
                $(this).remove();
              }
            });
          };
          opts.hide = { delay: 200, duration: 0 }; // this is to give user 200ms to enter the tooltip popup before it closes
        }

        delete opts.delay;

        $this.tooltip($.extend({
          show:     { delay: 100, duration: 1 },
          hide:     false,
          items:    opts.content ? '*' : undefined
        }, opts))[0];

        $this = null;

        return this;
      });
    }
  };
})(jQuery);
