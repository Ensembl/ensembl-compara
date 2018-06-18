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

Ensembl.Panel.Glossary = Ensembl.Panel.extend({

  init: function () {
    var panel = this;
    this.base();
  
    this.glossaryRestURL      = this.params['glossary_search_endpoint'];
    this.elLk.glossaryForm    = this.el.find('._glossary_search');
    this.elLk.glossaryInput   = this.el.find('input[name="query"]');
    this.elLk.glossaryButton  = this.el.find('._rest_search');
    this.elLk.glossaryResults = this.el.find('._glossary_results');

    this.elLk.glossaryButton.on('click', function(e) {
      panel.fetchGlossary();
      e.preventDefault();
    });
  },

  fetchGlossary: function() {

    this.elLk.glossaryResults.children().hide().end().removeClass('hidden').append('<p>Loading ...</p>');

    $.ajax({
      url       : this.glossaryRestURL + '&q=' + this.elLk.glossaryInput.val(),
      dataType  : 'jsonp',
      context   : this,
      success   : function(json) { this.showGlossaryResults(json); this.elLk.glossaryResults.children('p').remove(); },
      error     : function(jqXHR) { this.showError((jqXHR.responseJSON || {}).error) }
    });
  },

  showGlossaryResults: function(data) {
    var list  = this.elLk.glossaryResults.children().filter('li').remove().end().show().find('ul');

    $.each(data._embedded.terms, function(obj) {
      console.log(obj.label);
    });
  },

  showError: function(err) {
    if (err) {
      if (err.match(/not recognize/)) {
        err = '';
      }
    } else {
      err = 'Error loading glossary results from OLS';
    }
    this.elLk.glossaryResults.children('li').show().end().children('p').html(err).show();
  }


});
