/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2021] EMBL-European Bioinformatics Institute
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
 * keepOnPage
 * jQuery plugin to keep an element always on the page when page scrolled vertically
 */

(function($) {

  $.keepOnPage = function (el, options) {
    /* options - object with following keys
     *  marginTop: Margin to be kept on top when fixing the element to the top
     *  onfix: Function to be called when element is fixed on top
     *  onreset: Function to be called when element's position is reverted back to original
     * Or alternatively, options can be one of the following strings
     * 'trigger' To externally trigger the outcome of window scroll on the keepOnPage instance
     * 'destroy' To remove the keepOnPage feature from an element
     */

    el = $(el);

    var eventId;

    if (el.data('keepOnPage')) {

      eventId = el.data('keepOnPage').eventId;

      if (options === 'trigger') {
        $(window).triggerHandler('scroll.keepOnPage_' + eventId, true);

      } else if (options === 'destroy') {
        $(window).off('.keepOnPage_' + eventId);
        el.removeData('keepOnPage');
      }

    } else if (options !== 'destroy') {

      var eventId = Math.random().toString().split('.')[1];

      el.data('keepOnPage', {active: false, eventId: eventId});

      $(window).on('load.keepOnPage_' + eventId + ' scroll.keepOnPage_' + eventId,
        $.extend({
          el      : el,
          options : options
        }, (function(el, defaults) {
          return {
            clone     : defaults.position === 'static' ? el.clone().hide().empty().css({ visibility: 'hidden', height: el.height(), width: el.width() }).insertAfter(el) : false,
            defaults  : defaults
          }
        })(el, {
          cssTop    : el.css('top'),
          offsetTop : el.offset().top,
          position  : el.css('position')
        })),
        function (e, force) {

          // in case the offset has been changed by third party, update it before we do any calculations
          if (!e.data.el.data('keepOnPage').active) {
            e.data.defaults.offsetTop = e.data.el.offset().top;
          }

          var displacement  = Math.max($(window).scrollTop() - e.data.defaults.offsetTop + e.data.options.marginTop, 0);
          var isRelative    = e.data.defaults.position === 'relative';
          var isChanging    = e.data.el.data('keepOnPage').active === !displacement;

          // only continue if it's a forced action or if there's a change required in the position or if displacement for a relatively placed element has been changed
          if (!force && !isChanging && (!displacement || !isRelative)) {
            return;
          }

          // save status
          e.data.el.data('keepOnPage').active = !!displacement;

          // replace the actual element with the clone if a 'static' positioned element is not being 'fixed'
          if (e.data.clone) {
            e.data.clone.css(force && displacement ? {height: e.data.el.height(), width: e.data.el.width()} : {}).toggle(!!displacement);
          }

          // change positon and top
          e.data.el.css(displacement ? isRelative ? { top: displacement } : { position: 'fixed', top: e.data.options.marginTop } : { position: e.data.defaults.position, top: isRelative ? e.data.defaults.cssTop : e.data.defaults.offsetTop });

          // call the required callback function
          if (isChanging) {
            ((displacement ? e.data.options.onfix : e.data.options.onreset) || $.noop).apply(e.data.el[0]);
          }
        }
      );
    }
  };

  $.fn.keepOnPage = function (options) {

    options = options || {};
    options.marginTop = options.marginTop || 0;

    this.each(function() {

      $.keepOnPage(this, options);
    });

    return this;

  };
})(jQuery);
