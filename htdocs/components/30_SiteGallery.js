/*
 * Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

Ensembl.Panel.SiteGalleryHome = Ensembl.Panel.Content.extend({

  init: function () {

    this.base.apply(this, arguments);

    this.elLk.form        = this.el.find('form[name=gallery_home]').remove('.js_param');
    this.elLk.dataType    = this.elLk.form.find('input[name=data_type]');
    this.elLk.identifier  = this.elLk.form.find('input[name=identifier]');
    this.elLk.species     = this.elLk.form.find('select[name=species]');

    this.formAction       = this.elLk.form.attr('action');

    this.initSelectToToggle();
    this.updateIdentifier();

    this.elLk.dataType.add(this.elLk.species).on('change', {panel: this}, function(e) { e.data.panel.updateIdentifier() });
  },

  initSelectToToggle: function () {
    var panel = this;

    this.elLk.species.find('option').addClass(function () {
      return panel.params['sample_data'][this.value]['variation'] ? '_stt__var' : '_stt__novar';
    });

    this.elLk.dataType.parent().addClass(function () {
      return $(this).find('[value=variation]').length ? '_stt_var' : '_stt_var _stt_novar';
    });

    this.elLk.species.selectToToggle();
  },

  updateIdentifier: function () {
    var species = this.elLk.species.val();

    if (!this.elLk.dataType.filter(':visible:checked').length) {
      this.elLk.dataType.filter(':visible').first().prop('checked', true);
    }

    this.elLk.identifier.val((this.params['sample_data'][species] || {})[this.elLk.dataType.filter(':checked').val()] || '');
    this.elLk.form.attr('action', this.formAction.replace('Multi',  species));
  }
});
