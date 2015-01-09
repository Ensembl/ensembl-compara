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

Ensembl.Panel.SpeciesList = Ensembl.Panel.extend({  
  init: function () {
    this.base();
    
    var reorder    = $('.reorder_species', this.el);
    var full       = $('.full_species', this.el);
    var favourites = $('.favourites', this.el);
    var container  = $('.species_list_container', this.el);
    var dropdown   = $('.dropdown_redirect',this.el);
    
    if (!reorder.length || !full.length || !favourites.length) {
      return;
    }
    
    $('.toggle_link', this.el).on('click', function () {
      reorder.toggle();
      full.toggle();
    });
    
    $('.favourites, .species', this.el).sortable({
      connectWith: '.list',
      containment: this.el,
      stop: function () {
        $.ajax({
          url: '/Account/Favourites/Save',
          data: { favourites: favourites.sortable('toArray').join(',').replace(/(favourite|species)-/g, '') },
          dataType: 'json',
          success: function (data) {
            container.html(data.list);
            dropdown.html(data.dropdown);
          }
        });
      }
    });
    
    $('select.dropdown_redirect', this.el).on('change', function () {
      Ensembl.redirect(this.value);
    });
  }
});
