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

Ensembl.Panel.CellTypeSelector = Ensembl.Panel.CloudMultiSelector.extend({
  updateSelection: function () {
    var panel = this;

    if(!this.changed) { return; }

    var params = {
      image_config: this.params.image_config
    };
    params[this.urlParam+'_on'] = encodeURIComponent(this.changed_on.join(','));
    params[this.urlParam+'_off'] = encodeURIComponent(this.changed_off.join(','));

    panel.reset_selection();
    $.ajax({
      url: '/' + Ensembl.species + '/Ajax/cell_type',
      data: params,
      context: this,
      complete: function() {
        var panels = ['FeaturesByCellLine','FeatureDetails',
                      'FeatureSummary','ViewBottom'];
        Ensembl.EventManager.trigger('partialReload');
        for(var i=0;i<panels.length;i++) {
          Ensembl.EventManager.triggerSpecific('updatePanel',panels[i]);
        }
      }
    });
    
    return true;
  }
});
