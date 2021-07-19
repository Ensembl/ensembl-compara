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

Ensembl.Panel.ModalContent = Ensembl.Panel.LocalContext.extend({
  constructor: function () {
    this.base.apply(this, arguments);
    
    Ensembl.EventManager.register('modalFormSubmit', this, this.formSubmit);
  },
  
  init: function () {
    var panel = this;

    this.activeLink = false;
    
    this.base();
        
    this.elLk.content = $('.modal_wrapper', this.el);
    
    $('a', this.elLk.links).on('click', function () {
      if (!$(this).hasClass('disabled')) {
        var link = $(this).parent();
        
        if (!link.hasClass('active')) {
          panel.elLk.links.removeClass('active');
          panel.getContent(link.addClass('active'), this.href);
        }
        
        link = null;
      }
      
      return false;
    });
    
    this.elLk.links.on('click', function (e) {
      e.stopPropagation();
      return $(this).children('a').trigger('click');
    });
    
    this.elLk.content.on('click', 'a.delete_bookmark', function () {
      Ensembl.EventManager.trigger('deleteBookmark', this.href.match(/id=(\d+)\b/)[1]);
    }).on('click', 'form div.select_all input', function () {
      $(this).parents('fieldset').find('input[type=checkbox]').prop('checked', this.checked);
    }).on('click', 'form.wizard input.back', function () {
      $(this).parents('form.wizard').append('<input type="hidden" name="wizard_back" value="1" />').submit();
    });
    
    this.initialize();
    this.initFromHash();
  },
  
  initialize: function () {
    this.addSubPanel();
    this.setSelectAll();
    
    this.elLk.dataTable = $('table.data_table', this.el);
    
    if (this.elLk.dataTable.length) {
      if (!this.dataTableInit) {
        $.extend(this, Ensembl.DataTable);
      }
      
      this.dataTableInit();
      this.el.togglewrap();
    }
    
    Ensembl.EventManager.trigger('validateForms', this.el);
    
    this.el.find('._ht').helptip();
    this.el.find('._stt').selectToToggle({}, this.el);
    this.el.find('._sdd').speciesDropdown();
  },

  initFromHash: function() {
    if (this.params.hash) {
      this.elLk.links.filter(':has(a.' + this.params.hash + ')').trigger('click');
    }
  },

  getContent: function (link, url) {
    this.elLk.content.html('<div class="panel"><div class="spinner">Loading Content</div></div>');

    var params = Ensembl.prepareRequestParams(url);
    
    $.ajax({
      url: params.requestURL,
      type: params.requestType,
      data: params.requestData,
      dataType: 'json',
      context: this,
      success: function (json) {
        if (json.redirectURL && json.redirectType === 'modal') {
          return this.getContent(link, json.redirectURL);
        } else if (json.redirectType === 'page') {
          return Ensembl.redirect(json.redirectURL);
        } else if (json.redirectType === 'download') {
          Ensembl.EventManager.trigger('modalClose');
          window.location.href = json.redirectURL;
          return;
        }
        
        // Avoid race conditions if the user has clicked another nav link while waiting for content to load
        if (typeof link === 'undefined' || link.hasClass('active')) {
          this.updateContent(json);
        }
      },
      error: function (e) {
        if (e.status !== 0) {
          this.displayErrorMessage(e.responseText);
        }
      }
    });
  },
  
  formSubmit: function (form, data) {
    data = data || form.serialize();

    $.ajax({
      url: form.attr('action'),
      type: form.attr('method'),
      data: data,
      dataType: 'json',
      context: this,
      iframe: !!form.find('input[type=file]').length,
      form: form,
      success: function (json) {
        if (json.redirectURL && json.redirectType === 'modal') {
          return json.modalTab ? Ensembl.EventManager.trigger('modalOpen', { href: json.redirectURL, rel: json.modalTab }) : this.getContent(undefined, json.redirectURL);
        }
        
        if (json.redirectType === 'download') {
          Ensembl.EventManager.trigger('modalClose');
          window.location.href = json.redirectURL; // not triggering reloadPage here as reloadPage will call destructor on existing panels
        } else if (json.success === true || json.redirectType === 'page') {
          Ensembl.EventManager.trigger('reloadPage', false, json.redirectType === 'page' ? json.redirectURL : false);
        } else if (this.el.is(':visible')) {
          this.updateContent(json);
        }
      },
      error: function (e) {
        if (e.status !== 0) {
          this.displayErrorMessage(e.responseText);
        }
      }
    });
    
    this.elLk.content.html('<div class="panel"><div class="spinner">Loading Content</div></div>');
    
    return false;
  },
  
  updateContent: function (json) {
    var panel = this;

    if (json.wrapper) {
      this.elLk.content.wrapInner(json.wrapper);
    }
  
    this.elLk.content.html(json.content);

    if ($('.modal_reload', this.el).length) {
      Ensembl.EventManager.trigger('queuePageReload', '', false, false, $('.modal_reload', this.el).attr('href'));
    }
    
    if ($('.export_buttons_preview', this.el).length) {
      $('.export_buttons_preview', this.el).on('click', function() {
        var action = $('input[name="' + this.name + '"]:hidden', panel.el);
        if (this.name === 'uncompressed') {
          window.location = $(action).val();
          Ensembl.EventManager.trigger('modalClose');
          return;
        }
        else if (this.name === 'gz') {
          $('form#export', this.el).attr('action', $(action).val())
            .find('input[name="compression"]').val('gz');
        }
        $('form#export', this.el).submit();
      });
    }
    this.initialize();
  },
  
  addSubPanel: function () {
    var panel  = this;
    var params = [];
    
    $('.ajax', this.elLk.content).each(function () {
      params.push([ $(this).parents('.js_panel')[0].id, 'Content' ]);
    });
    
    $('.js_panel', this.elLk.content).each(function () {
      var panelType = $('input.subpanel_type', this).val();
      
      if (panelType && !(panel instanceof Ensembl.Panel[panelType])) {
        params.push([ this.id, panelType ]);
      }
    });
    
    for (var i in params) {
      Ensembl.EventManager.trigger('destroyPanel', params[i][0], 'empty');
      Ensembl.EventManager.trigger('createPanel',  params[i][0], params[i][1]);
    }
  },
  
  setSelectAll: function () {
    $('form div.select_all input', this.elLk.content).prop('checked', function () {
      return $(this).parents('fieldset').find('input[type=checkbox]:not(:checked)').length - 1 <= 0; // -1 for the select_all checkbox itself
    });
    this.elLk.content.find('input._selectall').on('change', function() {
      $(this).parents('div._selectall').find('input[type=checkbox]').prop('checked', this.checked);
    });
  },

  displayErrorMessage: function (message) {
    this.elLk.content.html('<div class="error ajax_error"><h3>Ajax error</h3><div class="error-pad"><p>Sorry, the page request failed to load.</p><pre></pre></div></div>').find('pre').text(message || '');
  }
});
