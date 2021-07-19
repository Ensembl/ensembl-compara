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

// JavaScript to control enabling, disabling and deleting of userdata files via the ManageData table 
Ensembl.Panel.ManageData = Ensembl.Panel.ModalContent.extend({

  init: function () {
    var panel = this;
    this.base();
    this.elLk.table = this.el.find("#ManageDataTable"); 

    this.el.find("._mu_button").each(
      function() {
        $(this).on({ click: function () {
          panel.elLk.url = $(this).attr("href");
          panel.elLk.table.find(".mass_update").each(
            function() {
              if ($(this).is(":checked")) {
                panel.elLk.url += ';record='+$(this).val();
              }
          });
          $(this).attr("href", panel.elLk.url);             
        }});
      }
    );

    // 'Select all' option
    this.elLk.selectAll = this.el.find("#selectAllFiles");
    this.elLk.selectAll.on({ click: function() {
      panel.elLk.table.find(".mass_update").each(
        function() {
          if (panel.elLk.selectAll.is(":checked")) {
            $(this).prop('checked', true);  
          }
          else {
            $(this).prop('checked', false);  
          }
        });
    }});

    // LocalCache clearing for new matrix interface
    this.el.find("._clear_localcache").each(
      function() {
        $(this).on({ click: function () {
          $(this).siblings().each(function(i, sib) {
            if ($(sib).hasClass('_trackhub_key')) {
              localStorage.removeItem($(sib).val());
            }
          });
        }});
      }
    );

  }

});
