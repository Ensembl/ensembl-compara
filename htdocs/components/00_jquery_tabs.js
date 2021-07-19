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

(function ($) {
  $.fn.tabs = function (targets, event) {

    if (this.length === targets.length) {

      var couples = [];

      this.each(function(i) {
        couples.push({button: $(this), target: targets.eq(i), event: event});
      });

      $.each(couples, function(i, couple) {

        couple.button.data('tabs', {target: couple.target, siblings: couples}).on(couple.event === 'click' ? 'click.tabs' : 'mouseenter.tabs', function() {
          $.each($(this).data('tabs').siblings, function(i, couple) {
            couple.button.add(couple.target).removeClass('active');
          });
          $(this).add($(this).data('tabs').target).addClass('active');
        });

      });

      couples = null;
    }

    return this;
  };
})(jQuery);
