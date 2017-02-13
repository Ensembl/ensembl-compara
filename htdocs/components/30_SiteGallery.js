/*
 * Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

Ensembl.Panel.SiteGallery = Ensembl.Panel.Content.extend({

  init: function () {
    this.base.apply(this, arguments);

    this.stickyMenu();

    this.el.find(".embiggen").each( 
      function() {
        $(this).on({ mouseover: function () { $(this).addClass('zoom');    } });
        $(this).on({ mouseout:  function () { $(this).removeClass('zoom'); } });
        $(this).on({ click:     function () { 
                                              var popup = $(this).next();
                                              // Reveal hidden div with form
                                              popup.removeClass('hide'); 
                                              /* Move form to the right, because trying to
                                              align it with static CSS is too much hassle! */
                                              var offset = popup.width() - 225;
                                              if (offset > 0) {
                                                popup.css('right', offset+'px');
                                              }
                                            } });
        // First child is the (x) button on the corner of the div
        $(this).next().children(":first").on({ click: function() { $(this).parent().addClass('hide'); } });
      }
    );

  },

  stickyMenu: function() {
    if (!this.elLk.menuBar) {
      this.elLk.menuBar = this.el.find('#gallery-toc');
    }
    this.elLk.menuBar.keepOnPage({
      marginTop: 10,
      onreset: function() {
        $(this).removeClass('sticky');
      },
      onfix: function() {
        $(this).addClass('sticky');
      }
    }).keepOnPage('trigger');
  }

});

Ensembl.Panel.SiteGalleryHome = Ensembl.Panel.Content.extend({

  init: function () {

    this.base.apply(this, arguments);

    this.elLk.form        = this.el.find('form[name=gallery_home]').remove('.js_param');
    this.elLk.dataType    = this.elLk.form.find('input[name=data_type]');
    this.elLk.identifier  = this.elLk.form.find('input[name=identifier]');
    this.elLk.species     = this.elLk.form.find('select[name=species]');

    this.formAction       = this.elLk.form.attr('action');

    this.initSelectToToggle();
    this.updateIdentifier();

    this.elLk.dataType.add(this.elLk.species).on('change', {panel: this}, function(e) { e.data.panel.updateIdentifier() });

    this.geneCache      = {};
    this.geneIDCache    = {};
    this.elLk.identifier.on('focus', {panel: this}, function(e) { e.data.panel.autocompleteGene() });
  },

  initSelectToToggle: function () {
    var panel = this;

    this.elLk.species.find('option').addClass(function () {
      return panel.params['sample_data'][this.value]['variation'] ? '_stt__var' : '_stt__novar';
    });

    this.elLk.dataType.parent().addClass(function () {
      return $(this).find('[value=variation]').length ? '_stt_var' : '_stt_var _stt_novar';
    });

    this.elLk.species.selectToToggle();
  },

  updateIdentifier: function () {
    var species = this.elLk.species.val();

    if (!this.elLk.dataType.filter(':visible:checked').length) {
      this.elLk.dataType.filter(':visible').first().prop('checked', true);
    }

    this.elLk.identifier.val((this.params['sample_data'][species] || {})[this.elLk.dataType.filter(':checked').val()] || '');
    this.elLk.form.attr('action', this.formAction.replace('Multi',  species));
  },

  // autocomplete on the identifier input field
  autocompleteGene: function () {
    var panel = this;
    this.elLk.identifier.autocomplete({
      minLength: 3,
      source: function(request, responseCallback) {
        var context = { // context to be passed to ajax callbacks
          panel     : panel,
          term      : request.term,
          key       : request.term.substr(0, 3).toUpperCase(),
          callback  : function(str, group) {
            var regexp = new RegExp('^' + $.ui.autocomplete.escapeRegex(str), 'i');
            return responseCallback($.map(group, function(val, geneLabel) {
              return regexp.test(geneLabel) ? val.label : null;
            }));
          }
        }

        if (context.key in panel.geneCache) {
          return context.callback(request.term, panel.geneCache[context.key]);
        }

        $.ajax({
          url: Ensembl.speciesPath + '/Ajax/autocomplete',
          cache: true,
          data: {
            q: context.key,
            species: panel.elLk.species.val()
          },
          dataType: 'json',
          context: context,
          success: function (json) {
            this.panel.geneCache[this.key] = json;
          },
          complete: function () {
            return this.callback(this.term, this.panel.geneCache[this.key]);
          }
        });
      }
    });
  }
});
