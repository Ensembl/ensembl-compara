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

Ensembl.Panel.DataExport = Ensembl.Panel.extend({

  init: function () {
    var panel = this;

    this.base();

    this.elLk.form      = this.el.find('form').first();
    this.elLk.images    = this.elLk.form.find('div._export_formats div').on('click', function() { panel.selectOption(this.firstChild.innerHTML); });
    this.elLk.dropdown  = this.elLk.form.find('select._export_formats').on('change', function() { panel.selectOption(this.value, true); });

    // change the button text for compressed and uncompressed formats
    this.elLk.form.find('input[name=compression]').on('change', function() {
      panel.changeButtonVal(!!this.value && this.checked ? 'Download' : 'Preview');
    }).trigger('change');
  },

  selectOption: function(val, dropdown) {
    this.elLk.images.removeClass('selected').filter(function() { return this.firstChild.innerHTML == val; }).addClass('selected');
    if (!dropdown) {
      this.elLk.dropdown.find('option[value=' + val + ']').prop('selected', true).end().selectToToggle('trigger');
    }
  },

  changeButtonVal: function(val) {
    this.elLk.form.find('input[type=submit]').val(val);
  }
});
