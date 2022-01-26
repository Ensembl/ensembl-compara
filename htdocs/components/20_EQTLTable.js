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

Ensembl.Panel.EQTLTable = Ensembl.Panel.Content.extend({
  init: function () {
    this.base();
    this.tableData = [];

    this.eQTLRestURL        = this.params['eqtl_rest_endpoint'].replace('http:', window.location.protocol);
    this.geneURLTemplate    = decodeURIComponent(this.params['eqtl_gene_url_template']);
    this.elLk.eQTLTable     = this.el.find('._variant_eqtl_table');

    this.elLk.eQTLTable.children().hide().end().removeClass('hidden').append('<p>Loading ' + this.elLk.eQTLTable.find('h2').text() + ' ...</p>');
    this.fetchEQTLTable();
    
  },

  fetchEQTLTable: function() {

    $.ajax({
      url       : this.eQTLRestURL,
      dataType  : 'json',
      context   : this,
      success   : function(json) { 
        
        var columns = Object.values(json['_embedded']['associations']);
        var nextUrl = json['_links']['next'] ? json['_links']['next']['href'] : '';

        this.tableData = this.tableData.concat(columns);

        // eQTL API can only return a maximum of 1000 rows at a time
        // so if we have nextUrl set, we make another query to grab the remaining data
        if(nextUrl){
          this.eQTLRestURL = nextUrl.replace('http:', window.location.protocol);;
          this.fetchEQTLTable();
        } else{
          this.elLk.eQTLTable.children().show();
          this.showEQTLTable(this.tableData); 
          this.elLk.eQTLTable.children('p').remove(); 
        }

      },
      error     : function(jqXHR) { this.showError((jqXHR.responseJSON || {}).error) }
    });
  },

  showEQTLTable: function(data) {
    var template  = this.geneURLTemplate;
    var table     = this.elLk.eQTLTable.children().filter('h3').remove().end().show().find('table').dataTable();

    // get rid of any existing rows
    for (var i = table.fnSettings().aoData.length -1; i >= 0; i--) {
      table.fnDeleteRow(i, false);
    }

    // combine data
    var dataCombined = {};
    $.each(data, function(i,obj) {
      var key = obj.gene_id + '-' + obj.qtl_group;
      if (!(key in dataCombined)) {
        dataCombined[key] = obj;
      }
    });
    data = null;

    // add rows from given data
    table.fnAddData($.makeArray($.map(dataCombined, function(obj) {
      return [[ '<a href="' + Ensembl.populateTemplate(template, {geneId: obj.gene_id}) + '">' + obj.gene_id + '</a>',
        obj.neg_log10_pvalue, obj.beta, obj.qtl_group
      ]];
    })), false);

    table.fnDraw();
  },

  showError: function(err) {
    if (err) {
      if (err.match(/not recognize/)) {
        err = '';
      }
    } else {
      err = 'Error loading eQTL data from REST';
    }
    this.elLk.eQTLTable.children('h3').show().end().children('p').html(err).show();
  }
});
