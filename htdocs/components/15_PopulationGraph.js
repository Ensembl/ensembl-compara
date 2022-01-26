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

Ensembl.Panel.PopulationGraph = Ensembl.Panel.Piechart.extend({
  init: function () {
    // Allele colours
    this.graphColours = {
      'A'       : '#008000',
      'T'       : '#FF0000',
      'G'       : '#FF9000',
      'C'       : '#0000FF',
      '-'       : '#000000',
      'default' : [ '#008080', '#FF00FF', '#7B68EE' ] // Other colours if the allele is not A, T, G, C or -
    };
    
    this.base();
  },

  toggleContent: function (el) {
    if (el.hasClass('closed') && !el.data('done')) {
      this.base(el);
      if (!this.canAddContent()) {
        return;
      }
      this.makeGraphs(this.el.find('.' + el.attr('rel') + ' .pie_chart > div[id^=graphHolder]').map(function() { return this.id.match(/\d+/).pop() }).toArray());
      el.data('done', true);
    } else {
      this.base(el);
    }
    
    el = null;
  },

  /*
    Up the prototype chain (Ensembl.Panel.Piechart -> Ensembl.Panel.Content)
    there is the `toggleable` method that gets executed during initialization.
    This method will trigger the toggleContent method in the current class.
    However:
    - there is no need for the toggleContent method to run at initialization
    - moreover, if the getContent method on Ensembl.Panel.Piechart hasn't completed
      by the time toggleContent is executed, calling this.makeGraphs will result in an error.
  */
  canAddContent: function () {
    // A rather dumb check to test that the getContent in the parent class has completed
    return Boolean(this.graphEls);
  }
});
