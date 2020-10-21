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

Ensembl.Panel.EQTLTable = Ensembl.Panel.Content.extend({
  init: function () {
    this.base();
    this.tableData = [];
    this.dataStart = 0;
    this.dataSize  = 1000;
    this.fetchingMore = false;

    this.eQTLRestURL        = this.params['eqtl_rest_endpoint'];
    this.geneURLTemplate    = decodeURIComponent(this.params['eqtl_gene_url_template']);
    this.elLk.eQTLTable     = this.el.find('._variant_eqtl_table');

    this.fetchEQTLTable();
  },

  fetchEQTLTable: function() {

    if(!this.fetchingMore){
      this.elLk.eQTLTable.children().hide().end().removeClass('hidden').append('<p>Loading ' + this.elLk.eQTLTable.find('h2').text() + ' ...</p>');
    }

    $.ajax({
      // url       : this.eQTLRestURL + '?start=' + this.dataStart + "&size="+this.dataSize,
      url       : this.eQTLRestURL,
      dataType  : 'json',
      context   : this,
      success   : function(json) { 
        
        var columns = Object.values(json['_embedded']['associations']);
        this.tableData = this.tableData.concat(columns);

        console.log(columns.length, columns );
        // eQTL API can only return a maximum of 1000 rows at a time
        // so if we have more than 999 records returned, we make another query to grab the remaining data
        if(columns.length > 999){
          this.dataStart = this.dataStart + this.dataSize;
          this.fetchingMore = true;
          this.fetchEQTLTable();
        } else{
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
      var key = obj.gene_id + '-' + obj.tissue_label;
      if (!(key in dataCombined)) {
        dataCombined[key] = obj;
      }
      dataCombined[key][obj.statistic] = obj.statistic === 'beta' ? obj.value : obj.pvalue;
    });
    data = null;

    // add rows from given data
    table.fnAddData($.makeArray($.map(dataCombined, function(obj) {
      return [[ '<a href="' + Ensembl.populateTemplate(template, {geneId: obj.gene_id}) + '">' + obj.gene_id + '</a>',
        obj.pvalue, obj.beta, obj.tissue_label
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
