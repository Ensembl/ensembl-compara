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

Ensembl.Panel.Interaction = Ensembl.Panel.extend({

  constructor: function (id, params) {
    this.base(id, params);
  },

  init: function () {
    var panel = this;
    this.base();
    var data = $('input[name="intr_metadata"]', this.el).val();
    this.elLk.metadataLink = $('.interactions-right .label a');
    this.elLk.speciesRows = $('.interactions-species table tbody tr');
    this.elLk.otherRows = $('.interactions-other table tbody tr');

    this.elLk.intr_metadata = data ? JSON.parse(data) : {};

    this.elLk.metadataLink.click(function() {
      panel.displayMetadata();
    });

    // Add description text near the page caption. [Quick and dirty hack]
    var sub_title = "Cross-species interactions imported from PHI-base, HPIDB and PlasticDB with exact matches to proteins in Ensembl.";
    var subtitleHtml = $('<span />').addClass('interactionsSubTitle').html(sub_title);
    var navHeading = $(this.el).parent().siblings('.nav-heading').addClass('interactionsNavHeading')
    var navHeadingCaption = navHeading.find('.caption'); 
    navHeadingCaption.after(subtitleHtml);
  },

  displayMetadata: function() {
    
    if ($('.metarow', this.el).length) {
      $('.metarow', this.el).toggle();
      return;
    }

    const speciesMetadata = this.elLk.intr_metadata.species;
    const otherMetadata = this.elLk.intr_metadata.other;
    var ele, label, value, metahtml;

    speciesMetadata && speciesMetadata.forEach((md, i) => {
      ele = this.elLk.speciesRows[i];
      metahtml = '<div class="meta">'
      md.forEach((meta) => {
        label = meta.label ? '<div class="label">' + meta.label + '</div>' : '';
        value = meta.value ? '<div class="value"><p>' + meta.value + '</p></div>' : '';
        metahtml += '<div>' + label + value + '</div>';
      });
      metahtml += '</div>'
      $(ele).after('<tr class="metarow"  style="background-color:#eee"><td colspan="10">' + metahtml + '</td></tr>')
    });

    otherMetadata && otherMetadata.forEach((md, i) => {
      var ele = this.elLk.otherRows[i]
      var metahtml = '<div class="meta">'
      md.forEach((meta) => {
        metahtml += '<div><div class="label">' + meta.label + '</div><div class="value">' + meta.value + '</div></div>';
      });
      metahtml += '</div>'
      $(ele).after('<tr class="metarow"  style="background-color:#eee"><td colspan="10">' + metahtml + '</td></tr>')
    });
  }
});
