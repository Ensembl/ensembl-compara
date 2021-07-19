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

Ensembl.Panel.SearchBox = Ensembl.Panel.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    this.elLk.img       = $('.search_image', this.el);
    this.elLk.sites     = $('.sites', this.el);
    this.elLk.siteInput = $('input', this.elLk.sites);
    this.elLk.menu      = $('.site_menu', this.el);
    this.elLk.input     = $('.query', this.el);
    this.elLk.select    = $('select[name=species]', this.el);
    
    this.label   = this.elLk.input[0].defaultValue;
    this.species = this.elLk.select.val();
    
    this.updateSearch(Ensembl.cookie.get('ENSEMBL_SEARCH'));
    
    if (this.label !== this.elLk.input.val()) {
      this.elLk.input.removeClass('inactive');
    }
    
    this.elLk.input.on({
      'click focus': function() {
        if (panel.label === this.value) {
          $(this).selectRange(0, 0);
        }
      },
      'keydown paste': function() {
        if (this.className.match('inactive')) {
          $(this).removeClass('inactive').val('');
        }
      },
      blur: function() {
        if (!this.value) {
          $(this).addClass('inactive').val(panel.label);
        }
      }
    });

    $('div', this.elLk.menu).on('click', function () {
      var name = this.className;
      
      panel.updateSearch(name);
      panel.elLk.menu.hide();
      
      Ensembl.cookie.set('ENSEMBL_SEARCH', name);
    });

    this.elLk.sites.on('click', function () {
      panel.elLk.menu.toggle();
    });
    
    $('form', this.el).on('submit', function () {
      if ((panel.elLk.input.val() === panel.label && panel.elLk.select.val() === panel.species) || panel.elLk.input.val() === '') {
        return false;
      }
    });
  },
  
  updateSearch: function (type) {
    var label = type ? this.elLk.menu.find('.' + type + ' input').val() : false;
    
    if (label) {
      this.elLk.img.attr('src', this.elLk.menu.find('.' + type + ' img').attr('src'));
      this.elLk.siteInput.val(type);
      
      if (this.elLk.input.val() === this.label) {
        this.elLk.input.val(label);
      }
      
      this.label = label;
    }
  }
});
