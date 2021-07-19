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

Ensembl.Panel.Exporter = Ensembl.Panel.ModalContent.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    this.config = {};
    
    $.each($('form.configuration', this.el).serializeArray(), function () { panel.config[this.name] = this.value; });
  },
  
  formSubmit: function (form) {
    var panel   = this;
    var checked = $.extend({}, this.config);
    var data    = {};
    var diff    = {};
    var i;
    
    $('input[type=hidden], input.as-param', form).each(function () { data[this.name] = this.value; });
    var skip     = {};
    $('input.as-param', form).each(function() { skip[this.name] = 1; });
    
    if (form.hasClass('configuration')) {
      $.each(form.serializeArray(), function () {
        if (!skip[this.name] && panel.config[this.name] !== this.value) {
          diff[this.name] = this.value;
        }
        
        delete checked[this.name];
      });
      
      // Add unchecked checkboxes to the diff
      for (i in checked) {
        diff[i] = 'no';
      }
      
      data.view_config = JSON.stringify(diff);
      
      $.extend(true, this.config, diff);
    }
    
    return this.base(form, data);
  }
});
