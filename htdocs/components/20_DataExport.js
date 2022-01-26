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

Ensembl.Panel.DataExport = Ensembl.Panel.extend({

  init: function () {
    var panel = this;
    this.base();

    this.elLk.form    = this.el.find('form').first();
    this.elLk.buttons = this.elLk.form.find('input.export_buttons');

    // Select format by clicking on image
    this.elLk.images = this.elLk.form.find('div._export_formats div');
    if (this.elLk.images.length == 1) {
      // If only one format, automatically enable download buttons
      this.elLk.buttons.removeClass('disabled').prop('disabled', 0);;
    }
    else {
      this.elLk.images.on('click',  function() { panel.selectOption(this.firstChild.innerHTML); });
    }

    // Or select via dropdown
    this.elLk.dropdown    = this.elLk.form.find('select._export_formats').on('change',  function() { panel.selectOption(this.value, true); });
    this.elLk.compression = this.elLk.form.find('input[name="compression"]');

    this.elLk.buttons.on('click', function() {
      if (panel.elLk.images.length == 1 || panel.elLk.dropdown.val() !== '') {
        panel.elLk.compression.val(this.name);
        panel.elLk.form.trigger('submit');
      }
    });

    // Highlight previosly selected option when users come back from preview
    this.elLk.dropdown.trigger('change');
  },

  selectOption: function(val, dropdown) {
    this.elLk.images.removeClass('selected').filter(function() { return this.firstChild.innerHTML == val; }).addClass('selected');
    if (!dropdown) {
      this.elLk.dropdown.find('option[value=' + val + ']').prop('selected', true).end().selectToToggle('trigger');
    }

    // Enable/disable download buttons
    this.elLk.buttons.toggleClass('disabled', val === '').prop('disabled', val === '');

    // Disable preview for RTF
    if (val === 'RTF') {
      this.elLk.buttons.filter('[name=preview]').prop('disabled', true).addClass('disabled');
    }
  }

});
