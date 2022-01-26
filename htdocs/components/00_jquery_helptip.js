/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2022] EMBL-European Bioinformatics Institute
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
  function build($this) {
    if ($this.data('uiTooltip')) {
      return;
    }
    var opts  = $this.data('opts')||{};

    opts.content  = opts.content  || ($this.data('title')||'').replace(/\n/g, '<br />') || $this.find('>._ht_tip').first().remove().text();
    opts.track    = opts.track    || $this.hasClass('_ht_track');
    opts.delay    = opts.delay    || $this.hasClass('_ht_delay') || $('<div>').html(opts.content).find('a[href],form').length;
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
      opts.origClose = opts.close || $.noop;
      opts.close = function(e, ui) {
        var $this = $(this);
        var close = $this.data('uiTooltip').options.origClose;
        ui.tooltip.on({
          'mouseenter.helptip': function() {
            $(this).clearQueue();
          },
          'mouseleave.helptip': function(e) {
            $(this).remove();
            e.data.close.call(e.data.element, e, ui, true); // return extra flag for calling method to recognise the delayed closing of helptip
          }
        }, { element: $this, close: close });
        close.call($this, e, ui);
      };
      opts.hide = { delay: 200, duration: 0 }; // this is to give user 200ms to enter the tooltip popup before it closes
    }

    delete opts.delay;

    $this.tooltip($.extend({
      show:     { delay: 100, duration: 1 },
      hide:     false,
      items:    '*',
      open:     function(e, ui) {
        if (e.originalEvent && e.originalEvent.type === 'focusin' && !$(e.originalEvent.currentTarget).is('input,textarea')) {
          ui.tooltip.remove();
          return false;
        }
        ui.tooltip.externalLinks();
      }
    }, opts));
  }

  $.fn.helptip = function (options) {
    if (typeof options === 'string') {
      build($(this));
      return this.tooltip.apply(this, arguments);
    } else {

      return this.each(function () {
        var opts  = $.extend({}, options || {});
        var $this = $(this);
        $this.data('opts',opts);
        // prevent browser helptip "winning"
        $this.data('title',$this.attr('title'));
        $this.removeAttr('title');
        $this.on('mouseover',function() { build($this); $this.tooltip('open'); return true; });

        return;
      });
    }
  };
})(jQuery);
