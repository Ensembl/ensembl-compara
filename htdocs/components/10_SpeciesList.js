/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016] EMBL-European Bioinformatics Institute
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

    this.elLk.container   = this.el.find('._species_fav_container');
    this.elLk.list        = this.el.find('._species_sort_container');
    this.elLk.dropdown    = this.el.find('select._all_species');
    this.elLk.buttonEdit  = this.el.find('a._list_edit');
    this.elLk.buttonDone  = this.el.find('a._list_done');
    this.elLk.buttonReset = this.el.find('a._list_reset');

    this.allSpecies       = this.params['species_list'];
    this.favTemplate      = this.params['fav_template'];
    this.listTemplate     = this.params['list_template'];
    this.urlTemplate      = this.params['species_url_template'];
    this.strainTemplate   = this.params['species_strain_url_template'];
    this.refreshURL       = this.params['ajax_refresh_url'];
    this.saveURL          = this.params['ajax_save_url'];
    this.displayLimit     = this.params['display_limit'];
    this.taxonOrder       = this.params['taxon_order'];
    this.taxonLabels      = this.params['taxon_labels'];

    this.elLk.buttonEdit.on('click', { panel: this }, function(e) {
      e.preventDefault();
      if (Ensembl.isLoggedInUser) {
        e.stopImmediatePropagation();
        e.stopPropagation();
        e.data.panel.toggleList(true);
      }
    });

    this.elLk.buttonDone.on('click', { panel: this }, function(e) {
      e.preventDefault();
      e.data.panel.toggleList(false);
    });

    this.elLk.buttonReset.on('click', { panel: this }, function(e) {
      e.preventDefault();
      e.data.panel.updateFav('');
      e.data.panel.toggleList(false);
    });

    this.elLk.dropdown.on('change', function() {
      var url = $(this).val();
      if (url) {
        window.location.href = url;
      }
    });

    this.refreshFav();
    this.renderDropdown();
  },

  renderFav: function () {
    this.elLk.container.empty();

    for (var i = 0; i < this.allSpecies.length; i++) {
      var species = this.allSpecies[i];

      if (!species.favourite || i >= this.displayLimit) { // first few species in the list are favourite
        break;
      }

      this.elLk.container.append(Ensembl.populateTemplate(this.favTemplate, {species: species}));
    }
  },

  refreshFav: function() {
    this.elLk.container.addClass('faded');
    if (Ensembl.isLoggedInUser) {
      $.ajax({
        url : this.refreshURL,
        context: this,
        dataType: 'json',
        success: function(allSpecies) {
          this.allSpecies = allSpecies;
          this.renderFav();
          this.renderList();
          this.elLk.container.removeClass('faded').externalLinks();
        }
      });
    } else {
      this.elLk.container.removeClass('faded').externalLinks();
    }
  },

  renderList: function() {
    var panel     = this;
    var template  = this.listTemplate;
    var fav       = this.elLk.list.find('ul._favourites').empty();
    var sp        = this.elLk.list.find('ul._species').empty();

    $.each(this.allSpecies, function(i, species) {
      if (!species.external) {
        (species.favourite ? fav : sp).append(Ensembl.populateTemplate(template, {species: species}));
      }
    });

    fav.add(sp).sortable({
      connectWith: '._species, ._favourites',
      containment: this.el,
      stop: function () {
        panel.updateFav(fav.sortable('toArray').join(',').replace(/species\-/g, ''));
      }
    });
  },

  toggleList: function(flag) {
    this.elLk.list.toggleClass('hidden', !flag);
    this.elLk.buttonEdit.toggle(!flag);
  },

  renderDropdown: function() {
    var template  = this.urlTemplate;
    var templateS = this.strainTemplate;
    var labels    = this.taxonLabels;
    var dropdown  = this.elLk.dropdown.children(':not(:first-child)').remove().end();
    var optgroups = $();

    var addOption = function(optgroup, species) {
      optgroup.append(
        '<option value="' + Ensembl.populateTemplate(template, {species: species}) + '">' +
        species.common + ( species.favourite ? (' ' + species.assembly ) : (' (' + species.name + ')') ) +
        '</option>'
      );
      if (species.strains) {
        optgroup.append('<option value="' + Ensembl.populateTemplate(templateS, {species: species}) + '">' + species.common + ' strains (' + species.name + ')</option>');
      }
    };

    $.each(this.allSpecies, function(i, species) {

      // favourites group
      if (species.favourite) {
        var optgroup = optgroups.filter('.favourites');
        if (!optgroup.length) {
          optgroup = $('<optgroup class="favourites" label="Favourites"></optgroup>');
          optgroups = optgroups.add(optgroup);
        }
        addOption(optgroup, species);
      }

      // taxon group
      if (!species.external) {
        var groupClass  = species.group;
        var optgroup    = optgroups.filter('.' + groupClass);
        if (!optgroup.length) {
          optgroup = $('<optgroup class="' + groupClass + '" label="' + (labels[species.group] || groupClass) + '"></optgroup>');
          optgroups = optgroups.add(optgroup);
        }
        addOption(optgroup, species);
      }
    });

    // add favourites on top
    optgroups.filter('.favourites').appendTo(dropdown);

    // add remaining optgroups acc to taxon order
    for (var i in this.taxonOrder) {
      optgroups.filter('.' + this.taxonOrder[i]).appendTo(dropdown);
    }
  },

  updateFav: function(favSpecies) {
    $.ajax({
      url: this.saveURL,
      context: this,
      data: { favourites: favSpecies },
      dataType: 'json',
      success: function (json) {
        if (json.updated) {
          this.refreshFav();
        }
      }
    });
  }
});
