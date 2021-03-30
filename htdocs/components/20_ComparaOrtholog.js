/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

Ensembl.Panel.ComparaOrtholog = Ensembl.Panel.Content.extend({
  init: function () {
    this.base.apply(this, arguments);
    
    Ensembl.EventManager.register('dataTableFilterUpdated', this, this.updateWithoutOrthologList);
    Ensembl.EventManager.register('dataTableFilterUpdated', this, this.updateDownloadButton);
  },

  updateDownloadButton: function (classNames) {
    var downloadButton = $('.export.modal_link')[0];
    var exportButtonUrl = downloadButton.href;
    // Remove the existing filtered_sets param
    if(exportButtonUrl.indexOf(';filtered_sets=') > 0){
      exportButtonUrl = exportButtonUrl.substring(0, exportButtonUrl.indexOf(';filtered_sets='));
    }

    // Append the new filtered_sets params
    downloadButton.href = exportButtonUrl + ';filtered_sets=' + classNames.join(',').replace(/\s/g, '');

  },
  updateWithoutOrthologList: function (classNames) {
    var noOrthoList = $('#no_ortho_species li');
    var noOrthoCount = 0;

    noOrthoList.each(function () {
      var listItem = this;
      var shouldDisplayItem = false;
      var classNamesLength = classNames.length;

      classNames.forEach(function (clName) {
        clName = $.trim(clName);

        if (classNamesLength > 1 && clName === 'all') {
          return;
        }

        if (listItem.className.indexOf(clName) > -1) {
          shouldDisplayItem = true;
        }
      });

      if (shouldDisplayItem === true) {
        $(listItem).show();
        noOrthoCount += 1;
      } else {
        $(listItem).hide();
      }
    });

    $('.no_ortho_count').text(noOrthoCount);

    if (noOrthoCount === 0) {
      $('#no_ortho_message_pad').hide();
    } else {
      $('#no_ortho_message_pad').show();
    }
  }
});
