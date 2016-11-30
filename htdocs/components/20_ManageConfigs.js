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

Ensembl.Panel.ManageConfigs = Ensembl.Panel.ModalContent.extend({

  init: function () {
    this.base.apply(this, arguments);

    this.elLk.table = this.el.find('._manage_configs');

    this.elLk.table.find('span').each(function() {
      var data = {};
      $(this).closest('tr').find('input[type=hidden]').each(function() {
        data[this.name.replace(/saved_config_/, '')] = this.value;
      });
      $(this).data(data);

    }).on('click', function(e) {
      e.preventDefault();
      var data = $(this).data();

      console.log(this.className, data);

      switch (this.className) {
        case 'save':
        break;
        case 'edit':
        break;
        case 'delete':
        break;
        case 'share':
          if (!data.account) {
            alert('Please login before share your configuration');
          } else {
            alert(window.location.href.replace(/(\&|\;)time=[^\;\&]+/, '') + ';share_config=' + data.name + '/' + data.code)
          }
        break;
      }
    });
  }
});
