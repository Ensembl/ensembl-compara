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

    this.elLk.glossaryResults.children().remove().end().removeClass('hidden').append('<p class="_loading">Loading ...</p>');

    $.ajax({
      url       : this.glossaryRestURL + '&rows=100&q=' + this.elLk.glossaryInput.val(),
      dataType  : 'json',
      context   : this,
      success   : function(json) { this.showGlossaryResults(json); this.elLk.glossaryResults.children('._loading').remove(); },
      error     : function(jqXHR) { this.showError((jqXHR.responseJSON || {}).error) }
    });
  },

  showGlossaryResults: function(data) {
    var count   = data.response.numFound;
    var results = data.response.docs;

    if (count > 0) {
      var message = '<p class="top-margin">Found ' + count + ' matching terms';
      if (count > 100) {
        message += ' - showing first 100';
      }
      message += ':</p>';
      this.elLk.glossaryResults.append(message);
      var list = this.elLk.glossaryResults.append('<dl>');
      var myRegEx = new RegExp('(' + this.elLk.glossaryInput.val() + ')', "ig");
      $.each(results, function(i,obj) {
        // Highlight matching terms
        var term    = obj.label.replace(myRegEx, '<span class="hl">' + "$1" + '</span>');
        var desc    = obj.description[0].replace(myRegEx, '<span class="hl">' + "$1" + '</span>');
        // Append to list
        list.append('<dt>' + term + '</dt><dd>' + desc + '</dd>');
      });
    }
    else {
      this.elLk.glossaryResults.append('<p>No results found.</p>');
    }
  },

  showError: function(err) {
    if (err) {
      if (err.match(/not recognize/)) {
        err = '';
      }
    } else {
      err = 'Error loading glossary results from OLS';
    }
    this.elLk.glossaryResults.append('<p>' + err + '</p>');
  }


});
