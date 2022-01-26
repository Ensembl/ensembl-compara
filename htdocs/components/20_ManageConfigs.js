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

Ensembl.Panel.ManageConfigs = Ensembl.Panel.ModalContent.extend({

  initialize: function () {
    var panel = this;

    this.base.apply(this, arguments);

    this.elLk.table = this.el.find('._manage_configs');

    this.elLk.table.find('span').each(function() {
      var data  = {};
      var $this = $(this);

      $this.closest('tr').find('input[type=hidden]').each(function() { // closest('tr') because edit icon is in a different 'td'
        data[this.name.replace(/saved_config_/, '')] = this.value;
      });

      data.account = !!data.account; // true/false only

      $this.data(data).filter(function() { return data.account; }).closest('tr').addClass('user-config');

      panel.setHelptip($this);

    }).on('click', {panel: this}, function(e) {
      e.preventDefault();
      var $this = $(this);
      var data = $this.data();

      switch (this.className) {
        case 'save':
          if (Ensembl.isLoggedInUser && !data.account) {
            e.data.panel.moveConfig(data.code);
          }
        break;
        case 'edit':
          e.data.panel.showEditDesc($this.closest('td'));
        break;
        case 'delete':
          $.when(e.data.panel.deleteConfig(data.code)).done(function() {
            Ensembl.EventManager.trigger('refreshConfigList');
          });
        break;
        case 'share':
          if (Ensembl.isLoggedInUser && data.account) {
            e.data.panel.showShareURL(e, window.location.href.replace(/(\&|\;)time=[^\;\&]+/, '') + ';share_config=' + data.name + '/' + data.code);
          }
        break;
      }
    });
  },

  setHelptip: function(el) {

    el.helptip({content : (function(el, data) {

      switch (el.prop('className')) {
        case 'save':    return Ensembl.isLoggedInUser ? data.account ? 'Already saved' : 'Save to account' : 'Please login to save configuration to your user account';
        case 'edit':    return 'Edit description';
        case 'delete':  return 'Delete configuration';
        case 'share':   return Ensembl.isLoggedInUser ? data.account ? 'Share configuration' : 'Please save this configuration before sharing it.' : 'Please login and save this configuration before sharing it.';
      }
    })(el, el.data())});
  },

  showEditDesc: function(td) {

    td.find('span, div').hide().end()
    .append(
      $('<textarea>' + (td.find('div').attr('class').match('empty') ? '' : td.find('div').html()) + '</textarea>')
    ).append(
      $('<a href="#" class="button left-margin">Save</a>').on('click', {panel: this}, function(e) {
        e.preventDefault();
        if (!this.className.match(/disabled/)) {
          e.data.panel.saveEditDesc($(this).closest('td'));
        }
      })
    ).append(
      $('<a href="#" class="small left-margin">Cancel</a>').on('click', {panel: this}, function(e) {
        e.preventDefault();
        if (!this.className.match(/disabled/)) {
          e.data.panel.cancelEditDesc($(this).closest('td'));
        }
      })
    );
  },

  saveEditDesc: function(td) {

    // disable textare and buttons at the beginning of the request
    td.find('textarea').prop('disabled', true).end().find('a').addClass('disabled');

    this._ajax({
      url: this.params['save_desc_url'],
      context: {panel: this, td: td},
      data: {code: td.closest('tr').find('input[name=saved_config_code]').val(), desc: td.find('textarea').val()},
      complete: function() {

        // enable the textarea and links once request is finished
        this.td.find('textarea').prop('disabled', false).end().find('a').removeClass('disabled');
      }
    });
  },

  cancelEditDesc: function(td) {
    td.find('span, div').show().end().find('textarea, a').remove();
  },

  moveConfig: function(code) {
    return this._ajax({
      url: this.params['move_config_url'],
      data: {code: code}
    });
  },

  deleteConfig: function(code) {
    return this._ajax({
      url: this.params['delete_config_url'],
      data: {code: code}
    });
  },

  showShareURL: function(e, link) {
    e.stopPropagation();
    if (!this.elLk.shareURLHolder) {
      this.elLk.shareURLHolder = $('<div class="manage-config-copy-url"><p>Copy this link:</p><input type="string" /></div>').appendTo(document.body);
    }
    this.elLk.shareURLHolder.show().css({left: e.clientX, top: e.clientY}).on('click', function(e) { e.stopPropagation(); }).find('input').val(link).selectRange(0, link.length);
    $(document).off('.hideShareURL').on('click.hideShareURL', {popup: this.elLk.shareURLHolder}, function(e) {
      if (e.which === 1) {
        e.data.popup.hide();
        $(document).off('.hideShareURL');
      }
    });
  },

  _ajax: function(params) {
    return $.ajax($.extend({
      context: {panel: this},
      dataType: 'json',
      success: function(json) {
        if (json.updated) {
          this.panel.getContent(undefined, this.panel.params.url);
        }
      }
    }, params));
  }
});
