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

    this.elLk.form    = this.el.find('form').first();
    this.downloadURL  = this.elLk.form.find('input[name=download_url]').remove().val();
    this.previewURL   = this.elLk.form.find('input[name=preview_url]').remove().val();

    this.elLk.form.find('input[name=compression]').on('change', function() {
      panel.elLk.form.attr('action', this.value === 'gz' && this.checked ? panel.downloadURL : panel.previewURL);
      panel.elLk.form.find('input[type=submit]').val(!!this.value && this.checked ? 'Download' : 'Preview');
    }).trigger('change');
  }
});
