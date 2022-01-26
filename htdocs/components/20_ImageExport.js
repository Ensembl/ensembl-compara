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

Ensembl.Panel.ImageExport = Ensembl.Panel.extend({

  init: function () {
    var panel = this;

    this.base();
    this.elLk.form = this.el.find('form').first();

    // Extension change for custom format dropdown
    this.elLk.extSwitch = this.elLk.form.find('select[name=image_format]').on('change', function() { panel.updateExtension(this.value); });
    // Extension change for PDF preset
    this.elLk.pdfSwitch = this.elLk.form.find('input[name=format]').on('change', function() { 
                            if (this.value == 'pdf') {
                              panel.updateExtension(this.value); 
                            }
                            else if (this.value == 'custom') {
                              // do nothing - wait until format is selected, as per code above
                            }
                            else {
                              // reset to default PNG
                              panel.updateExtension('png'); 
                            }
                          });
  },

  updateExtension: function(newExt) {
    this.elLk.fileName  = this.elLk.form.find('input[name=filename]');
    var oldName         = this.elLk.fileName.val();
    var regex           = /\.(\w)*$/i;
    var newName         = oldName.replace(regex, '.' + newExt);
    this.elLk.fileName.val(newName);
  }


});
