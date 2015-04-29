/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
 * Not yet tested in all scenarios
 */

(function($) {

  $.keepOnPage = function (el, options) {
    /* options
     *  marginTop: Margin to be kept on top when fixing the element to the top
     *  spaced: Flag if true, will keep the actual space of the element clear while its fixed to the top
     *  onfix: Function to be called when element's position is set 'fixed'
     *  onreset: Function to be called when element's position is reverted back to original
     */

    el = $(el);

    if (el.data('keepOnTop')) {

      if (options === 'trigger') {
        $(window).triggerHandler('scroll.keepOnTop', true);
      }
    } else {

      el.data('keepOnTop', {});

      $(window).on('load.keepOnTop scroll.keepOnTop', {
        el        : el,
        options   : options,
        clone     : options.spaced ? el.clone().hide().empty().css({ visibility: 'hidden' }).insertAfter(el) : false,
        defaults  : {
          top       : el.offset().top,
          position  : el.css('position')
      }}, function (e, force) {
        var fixed = e.data.defaults.top - e.data.options.marginTop <= $(window).scrollTop();
        if (!force && e.data.el.data('keepOnTop').fixed === fixed) {
          return;
        }
        e.data.el.data('keepOnTop', {fixed: fixed});
        e.data.el.css(fixed ? { position: 'fixed', top: e.data.options.marginTop } : { position: e.data.defaults.position, top: e.data.defaults.top });
        if (e.data.clone) {
          e.data.clone.css(fixed ? {height: e.data.el.height() - 2, width: e.data.el.width()} : {}).toggle(fixed);  // -2 is just to prevent an possible jumpy effect
        }
        ((fixed ? e.data.options.onfix : e.data.options.onreset) || $.noop).apply(e.data.el[0]);
      });
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



