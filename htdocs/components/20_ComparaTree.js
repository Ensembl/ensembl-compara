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

Ensembl.Panel.ComparaTree = Ensembl.Panel.ImageMap.extend({
  init: function () {
    this.base.apply(this, arguments);

    this.elLk.highlightLink = this.el.find('.switch_highlighting');

    this.elLk.highlightLink.on('click', function(e) {
      var el = $(this);

      e.preventDefault();

      Ensembl.cookie.set('gene_tree_highlighting', el.hasClass('on') ? 'off' : 'on');

      // the page is reloaded after clicked on the switching link and the cookie value is inversed
      // might need to find a better way to do this
      Ensembl.LayoutManager.reloadPage();
    });
  }
});