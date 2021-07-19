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

Ensembl.Panel.SpeciesList = Ensembl.Panel.extend({
  init: function () {
    this.base();

    this.elLk.container   = this.el.find('._species_fav_container');
    this.elLk.list        = this.el.find('._species_sort_container');
    this.elLk.dropdown    = this.el.find('select._all_species');
    this.elLk.finder      = this.el.find('.finder input');
    this.elLk.buttonEdit  = this.el.find('a._list_edit');
    this.elLk.buttonDone  = this.el.find('a._list_done');
    this.elLk.buttonReset = this.el.find('a._list_reset');

    this.allSpecies       = this.params['species_list'] || [];
    this.allStrains       = this.params['strains_list'] || [];
    this.favTemplate      = this.params['fav_template'];
    this.listTemplate     = this.params['list_template'];
    this.refreshURL       = this.params['ajax_refresh_url'];
    this.saveURL          = this.params['ajax_save_url'];
    this.displayLimit     = this.params['display_limit'];
    this.favText          = this.params['fave_text'];
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
    //this.initAutoComplete();
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


  initAutoComplete: function() {
    var panel = this;
    this.elLk.finder.autocomplete({
      minLength: 3,
      source: function(request, response) {
        var speciesList = $();
        $.each(panel.allSpecies, function(i, species) {
          var label = species.common === species.name ? species.name : species.common + ' (' + species.name + ')'
          var spEntry = {'label' : label, 'url' : species.homepage};
          speciesList.push(spEntry);
        }); 
        // Add strain groups
        $.each(panel.allStrains, function(i, strain) {
          var spEntry = {'label' : strain.common + ' (' + strain.name + ')', 'url' : strain.homepage};
          speciesList.push(spEntry);
        }); 
        
        response(panel.filterArray(speciesList, request.term));
      }
    }).data("ui-autocomplete")._renderItem = function (ul, item) {
      ul.addClass('ss-autocomplete');
      // highlight the term within each match
      var regex = new RegExp("(?![^&;]+;)(?!<[^<>]*)(" + $.ui.autocomplete.escapeRegex(this.term) + ")(?![^<>]*>)(?![^&;]+;)", "gi");
      item.label = item.label.replace(regex, "<span class='ss-ac-highlight'>$1</span>");
      return $("<li/>").data("ui-autocomplete-item", item).addClass('ss-ac-result-li').append("<a href='" + item.url + "' class='ss-ac-result'>" + item.label + "</a>").appendTo(ul);
    };
  },

  filterArray: function(array, term) {
    term = term.replace(/[^a-zA-Z0-9 ]/g, '').toUpperCase();
    var matcher = new RegExp( $.ui.autocomplete.escapeRegex(term), "i" );
    var matches = $.grep( array, function(item) {
      return item && matcher.test( item.label.replace(/[^a-zA-Z0-9 ]/g, '') );
    });
    matches.sort(function(a, b) {
      // give priority to matches that begin with the term
      var aBegins = a.label.toUpperCase().substr(0, term.length) == term;
      var bBegins = b.label.toUpperCase().substr(0, term.length) == term;

      if (aBegins == bBegins) {
        if (a.label == b.label) return 0;
        return a.label < b.label ? -1 : 1;
      }
      return aBegins ? -1 : 1;
    });
    return matches;
  },

  renderDropdown: function() {
    var panel         = this;
    var labels        = this.taxonLabels;
    var dropdown      = this.elLk.dropdown.children(':not(:first-child)').remove().end();
    var optgroups     = $();
    var favSpecies    = $.map(this.allSpecies, function(sp) { return sp.favourite ? sp: null } );
    var sortedSpecies = this.allSpecies.slice(0).sort(function (a, b) { return a.common > b.common ? 1 : -1 });
    var favText       = this.favText;

    // favourites group
    $.each(favSpecies, function(i, species) {
      var optgroup = optgroups.filter('.favourites');
      if (!optgroup.length) {
        optgroup = $('<optgroup class="favourites" label="' + favText + '"></optgroup>');
        optgroups = optgroups.add(optgroup);
      }
      panel.addOption(optgroup, species, true);
    });

    // taxon group
    $.each(sortedSpecies, function(i, species) {

      if (!species.external) {
        var groupClass  = species.group;
        var optgroup    = optgroups.filter('.' + groupClass);
        if (!optgroup.length) {
          optgroup = $('<optgroup class="' + groupClass + '" label="' + (labels[species.group] || groupClass) + '"></optgroup>');
          optgroups = optgroups.add(optgroup);
        }
        panel.addOption(optgroup, species);
      }
    });

    // add favourites on top
    optgroups.filter('.favourites').appendTo(dropdown);

    // add remaining optgroups acc to taxon order
    for (var i in this.taxonOrder) {
      optgroups.filter('.' + this.taxonOrder[i]).appendTo(dropdown);
    }
  },

  addOption: function(optgroup, species, favSection) {
    optgroup.append(
      '<option value="' + species.homepage + '">' +
      species.common + 
      '</option>'
    );
    if (!favSection && species.strainspage) {
      optgroup.append('<option value="' + species.strainspage + '">' + species.straintitle + ' ' + species.strain_type + '</option>');
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
