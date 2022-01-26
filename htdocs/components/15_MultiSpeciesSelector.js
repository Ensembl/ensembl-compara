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

Ensembl.Panel.MultiSpeciesSelector = Ensembl.Panel.MultiSelector.extend({
  updateSelection: function () {
    var params            = [ 's', 'r', 'g' ]; // Multi-species parameters
    var existingSelection = {};
    var urlParams         = [];
    var species           = [];
    var i, j, k;
    
    for (var s in Ensembl.multiSpecies) {
      existingSelection[Ensembl.multiSpecies[s].s] = parseInt(s, 10);
    }
    
    for (i = 0; i < this.selection.length; i++) {
      j = existingSelection[this.selection[i]];
      
      if (typeof j !== 'undefined') {       
        k = params.length;
        
        while (k--) {
          if (Ensembl.multiSpecies[j][params[k]]) {
            if (params[k] === 's') {
              species.push('s' + (i + 1) + '=' + Ensembl.multiSpecies[j].s);
            } else {
              urlParams.push(params[k] + (i + 1) + '=' + Ensembl.multiSpecies[j][params[k]]);
            }
          }
        }
      } else {
        species.push('s' + (i + 1) + '=' + this.selection[i]);
      }
    }
    
    if (this.selection.join(',') !== this.initialSelection) {
      $.ajax({
        url: '/' + Ensembl.species + '/Ajax/multi_species?' + species.join(';'),
        context: this,
        complete: function () {
          Ensembl.redirect(this.elLk.form.attr('action') + '?' + Ensembl.cleanURL(this.elLk.form.serialize() + ';' + species.join(';') + ';' + urlParams.join(';')));
        }
      });
    }
    
    return true;
  }
});