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

(function ($) {
  $.fn.dynaLoad = function (options) {

    options = options || {};

    return this.each(function () {
      var el    = $(this);
      var data  = el.data('dynaLoad') || {};

      if (data.loaded && (!options.url || options.url === data.url)) {
        return;
      }

      options.url             = options.url             || data.url             || el.find('a').first().attr('href');
      options.fallBack        = options.fallBack        || data.fallBack        || el.find('a').first().text() || 'Request failed';
      options.responseFilter  = options.responseFilter  || data.responseFilter  || function (response) { return response; };
      options.complete        = options.complete        || data.complete        || $.noop;
      options.loaded          = true;

      el.empty().data('dynaLoad', options);

      if (!options.url) {
        el.html(options.fallBack);
      } else {
        $.ajax({
          cache: true,
          context: el,
          url: options.url,
          dataType: 'html',
          success: function (response) {
            this.html(this.data('dynaLoad').responseFilter(response) || this.data('dynaLoad').fallBack);
          },
          error: function() {
            this.html(this.data('dynaLoad').fallBack).data('dynaLoad').loaded = false;
          },
          complete: function() {
            this.data('dynaLoad').complete.call(this);
          }
        });
      }
    });
  };
})(jQuery);
