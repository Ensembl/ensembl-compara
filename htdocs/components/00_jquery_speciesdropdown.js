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
 * speciesDropdown: Javascript counterpart for E::W::Form::Element::SpeciesDropdown
 * Extension of filterableDropdown to add species icons to the tags
 * Reserverd classname prefix: _sdd
 **/
(function ($) {
  $.fn.speciesDropdown = function (options) {
  /*
   * options: same as accepted by filterableDropdown
   */

    return this.each(function () {
      $.speciesDropdown($(this), options);
    });
  };

  $.speciesDropdown = function (el, options) {

    if (options && options.change) {
      el.data('speciesDropdown', { change: options.change });
    }

    $.filterableDropdown(el, $.extend({}, options, {
      'change': function() {
        var data = $(this).find('._fd_tag').each(function() {
          this.style.backgroundImage = this.style.backgroundImage.replace(/[^\/]+\.png/, $($(this).data('input')).val() + '.png');
        }).end().data('speciesDropdown');
        if (data) {
          data.change.apply(this, arguments);
        }
        data = null;
      }
    }));
  };
})(jQuery);