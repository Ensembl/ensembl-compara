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
 * zMenuLink - Overrides default behaviour of a link to display zmenu instead
 **/
(function ($) {
  $.fn.zMenuLink = function () {

    return this.on('click.zmenulink', function (e) {
      e.preventDefault();

      var link = $($(this).siblings('._zmenu_link')[0] || this);

      Ensembl.EventManager.trigger('makeZMenu', link.attr('href').replace(/\W/g, '_'), { event: e, area: { link: link }}); // unique zmenu for every href
    });
  }
})(jQuery);
