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

Ensembl.Panel.ConfigManager = Ensembl.Panel.ModalContent.extend({
  constructor: function (id, params) {
    this.base(id, params);
  },

  init: function () {
    var panel = this;
    
    this.base();
    
    Ensembl.EventManager.register('modalPanelResize', panel, function () {
      this.el.togglewrap('update');
    });
    
    var forms = $('form', this.el); // make reference to forms before detaching content for modal overlay
    
    this.elLk.recordTypes  = $('.records .record_type', this.el);
    this.elLk.tables       = $('table',                 this.elLk.recordTypes);
    this.elLk.shareConfig  = $('.share_config',         this.el).detach(); // will be put into the modal overlay;
    this.elLk.editSets     = $('.edit_config_set',      this.el).detach(); // will be put into the modal overlay;
    this.elLk.saveAll      = $('.save_all_config_set',  this.el).detach(); // will be put into the modal overlay;
    this.elLk.noRecords    = $('.no_records',           this.el);
    this.elLk.resetAll     = $('.reset_all',            this.el);
    this.elLk.editTypes    = $('div.record_type',       this.elLk.editSets);
    this.elLk.editTable    = $('table',                 this.elLk.editTypes);
    this.elLk.editRecord   = $('.edit_record',          this.elLk.editSets);
    this.elLk.editSelected = $('input.selected',        this.elLk.editSets);
    this.elLk.editId       = $('.config_key',           this.elLk.editSets);
    this.elLk.addSet       = $('.add_set',              this.elLk.editSets);
    this.elLk.saveToGroup  = $('.groups',               this.elLk.addSet);
    this.elLk.addHeader    = $('.add_header',           this.elLk.editSets);
    this.elLk.editHeader   = $('.edit_header',          this.elLk.editSets);
    this.elLk.setsHeader   = $('.config_header',        this.elLk.editHeader);
    this.elLk.saveSets     = $('.sets ul',              this.elLk.saveAll);
    this.elLk.saveConfigs  = $('.configs ul',           this.elLk.saveAll);
    this.elLk.saveHeader   = $('.config_header',        this.elLk.saveAll);
    this.elLk.shareURL     = $('.share_url',            this.elLk.shareConfig);
    this.elLk.shareGroups  = $('.share_groups',         this.elLk.shareConfig);
    this.elLk.shareGroup   = $('input.group',           this.elLk.shareConfig);
    this.elLk.shareId      = $('.config_key',           this.elLk.shareConfig);
    this.elLk.shareHeader  = $('.config_header',        this.elLk.shareConfig);
    
    this.elLk.addSet.validate({
      validate: function (isValid) {
        if (isValid) {
          isValid = !!panel.elLk.addSet.find('input.selected:checked').length;
        }
        
        return isValid;
      }
    });
    
    forms.on('submit', function () { return panel.formSubmit($(this)); });
    
    this.elLk.tables.on('click', '.expand, .collapse', function () {
      var el  = $(this);
      var row = el.parents('tr');
      
      el.add(el.siblings('a')).add(row.siblings('.' + row[0].className.replace(/ /g, '.'))).toggle();
      
      if (el.hasClass('expand') && !el.data('hasConfig')) {
        var table = el.parents('table').dataTable();
            row   = row[0];
            
        table.fnOpen(row, '<div class="spinner"></div>').className = row.className;
        
        el.data('hasConfig', $.ajax({
          url: this.href,
          cache: false,
          success: function (html) {
            el.data('hasConfig', true);
            
            var newRow = $(table.fnOpen(row, html, 'details')).addClass(row.className).togglewrap('update');
            var sets   = newRow.find('.editables_list');
            
            if (sets.children().length === 0) {
              sets.parent().hide();
            }
            
            table.fnUpdate(row.cells[1].innerHTML + '<div class="hidden">' + html + '</div>', row, 1);
            
            el = row = newRow = sets = table = null;
          }
        }));
      } else {
        el = row = null;
      }
      
      return false;
    });
    
    // Activate, save and delete buttons
    this.elLk.tables.on('click', 'a.edit', function (e) {
      e.preventDefault();
      
      $.ajax({
        url: this.href,
        context: this,
        dataType: 'json',
        success: function (json) {
          if (panel[json.func]) {
            panel[json.func]($(this).parents('tr'), json);
          } else if (json.redirectURL) {
            Ensembl.EventManager.trigger('modalOpen', { href: json.redirectURL, rel: json.modalTab });
          }
        }
      });
    });
    
    this.elLk.tables.on('click', 'a.share_record', function () {
      var el     = $(this);
      var share  = el.data('share');
      var record = panel.params.records[el.parents('tr').data('configId')];
      var url, groups;
      
      panel.elLk.shareHeader.html(record.name);
      panel.elLk.shareId.val(record.id);
      
      Ensembl.EventManager.trigger('modalOverlayShow', panel.elLk.shareConfig);
      
      if (share) {
        if (share.groups) {
          panel.elLk.shareGroup.prop('checked', function () { return !!share.groups[this.value]; });
          groups = true;
        }
        
        if (share.url) {
          panel.elLk.shareURL.val(share.url).show().select();
          url = true;
        }
      }
      
      if (!groups) {
        panel.elLk.shareGroup.prop('checked', false);
      }
      
      if (!url) {
        panel.elLk.shareURL.hide();
      }
      
      panel.elLk.shareLink = el;
      el = null;
      
      return false;
    });
    
    this.elLk.tables.on('click', 'a.edit_record', function () {
      var record = panel.params.records[$(this).parents('tr').data('configId')];
      
      panel.elLk.setsHeader.html(record.name);
      panel.elLk.addSet.add(panel.elLk.addHeader).hide();
      panel.elLk.editRecord.add(panel.elLk.editHeader).show();
      panel.elLk.editId.val(record.id);
      
      panel.updateEditTable(record.group + '.' + record.groupId, record);
      
      Ensembl.EventManager.trigger('modalOverlayShow', panel.elLk.editSets);
      
      return false;
    });
    
    this.elLk.tables.on('click', '._ht', function () {
      $(this).data('uiTooltip').close();
    });
    
    this.elLk.editSets.on('click', '.add_to_set', function () {
      var tr = $(this).parents('tr');
      
      if (!tr.hasClass('disabled')) {
        tr.toggleClass('added');
      }
      
      var added = tr.hasClass('added');
      
      if (panel.params.recordType === 'set') {
        tr.siblings('.' + (panel.params.editables[this.rel].codes.join(', .') || '_')).not('.added')[added ? 'addClass' : 'removeClass']('disabled');
      }
      
      panel.elLk.editSelected.filter('.' + this.rel).prop('checked', added);
      panel.elLk.addSet.filter(function () { return this.style.display !== 'none'; }).validate();
      
      tr = null;
      
      return false;
    });
    
    $('a.create_set', this.el).on('click', function () {
      var type = panel.elLk.editSets.find('input.record_type');
      
      if (type.length > 1) {
        type = type.first().prop('checked', true); // Reset form
      }
      
      panel.updateEditTable(type.val());
      
      panel.elLk.editRecord.add(panel.elLk.editHeader).hide();
      panel.elLk.addSet.find('input[name=name], textarea').val('').end().validate(); // Reset form. Validate to remove error messages, but this won't disable the save button
      panel.elLk.addSet.find('.save').addClass('disabled').prop('disabled', true);   // Disable the save button because a name is required
      panel.elLk.addSet.add(panel.elLk.addHeader).show();
      
      Ensembl.EventManager.trigger('modalOverlayShow', panel.elLk.editSets);
      
      type = null;
      
      return false;
    });
    
    $('input.record_type', this.elLk.editSets).on('click', function () {
      panel.elLk.saveToGroup[this.value === 'group' ? 'show' : 'hide']();
      panel.updateEditTable(this.value + (this.value === 'group' ? '.' + panel.elLk.saveToGroup.find('input.group:checked').val() : ''));
      Ensembl.EventManager.trigger('modalPanelResize');
    });
    
    $('input.group', this.elLk.saveToGroup).on('click', function () {
      panel.updateEditTable(($(this).hasClass('suggested') ? 'suggested' : 'group') + '.' + this.value);
      Ensembl.EventManager.trigger('modalPanelResize');
    });
    
    $('.make_url', this.elLk.shareConfig).on('click', function () {
      var share = panel.elLk.shareLink.data('share');
      
      function showShare(shareURL) {
        share     = share || {};
        share.url = shareURL;
        
        panel.elLk.shareURL.val(shareURL).show().select();
        panel.elLk.shareLink.data('share', share);
      }
      
      if (share && share.url) {
        showShare(share.url);
      } else {
        $.ajax({ url: panel.elLk.shareLink[0].href, cache: false, success: showShare });
      }
    });
    
    $('.cancel, .continue', this.elLk.saveAll).on('click', function () {
      Ensembl.EventManager.trigger('modalOverlayHide');
      
      if ($(this).hasClass('continue')) {
        panel.elLk.saveAllLink.trigger('click');
      }
    });
    
    this.elLk.shareGroup.on('click', function () {
      var share   = panel.elLk.shareLink.data('share') || {};
      var disable = true;
      
      share.groups = share.groups || {};
      share.groups[this.value] = this.checked;
      
      for (var i in share.groups) {
        if (share.groups[i]) {
          disable = false;
          break;
        }
      }
      
      panel.elLk.shareGroups[disable ? 'addClass' : 'removeClass']('disabled').prop('disabled', disable);
      panel.elLk.shareLink.data('share', share);
    });
    
    this.elLk.shareConfig.add(this.elLk.editSets).find('form').on('submit', function () { Ensembl.EventManager.trigger('modalOverlayHide'); });
    
    $('form', this.elLk.resetAll).on('submit', function () {
      panel.elLk.resetAll.hide();
    });
    
    forms = null;
  },
  
  initialize: function () {
    // This must be done before the base initialize, which sets up data tables, adding classes to the table rows
    $('.records table tbody tr', this.el).each(function () {
      $(this).data('configId', this.className);
    });
    
    this.base();
  },
  
  updateEditTable: function (tableFilter, record) {
    var table = this.elLk.editTypes.hide().filter('.' + tableFilter).show().find('table').dataTable();
    
    this.elLk.editSelected.filter(':checked').prop('checked', false);
    
    table.find('tr').removeClass('added disabled');
    table.fnDraw();
    
    if (record) {
      var rows  = table.find('tbody tr');
      var added = [];
      
      for (var i in record.editables) {
        added.push('.' + i);
      }
      
      rows.filter(added.join(', ')).addClass('added');
      
      // When editing the sets for a config, all sets that already have a config of the same code must be disabled
      rows.filter('.' + (record.codes.join(', .') || '_')).not('.added').addClass('disabled');
      
      this.elLk.editSelected.filter(added.join(', ')).prop('checked', true);
      
      rows = null;
    }
    
    table = null;
  },
  
  // Saves updates to name and description fields in the table
  saveEdit: function (param, value, td) {
    var id = td.parent().data('configId');
    
    td.togglewrap('update').find('._ht').helptip();
    
    if (param === 'name') {
      this.params.records[id].name = value;
    }
    
    $.ajax({
      url: td.find('a.save').attr('href'),
      data: { param: param, value: value },
      cache: false,
      success: function (response) {
        if (response === 'success' && param === 'name') {
          Ensembl.EventManager.trigger('updateSavedConfig', { changed: { id: id, name: value } });
        }
      }
    });
    
    td = null;
  },
    
  addTableRow: function (data) {
    var panel = this;
    
    $.ajax({
      url: this.params.updateURL,
      data: { config_keys: data.configKeys },
      traditional: true,
      cache: false,
      dataType: 'json',
      success: function (json) {
        var table, rows;
        
        for (var i in json.tables) {
          rows = $(json.tables[i]).find('tbody tr').filter(function () { return !panel.params.records[this.className]; });
          
          if (rows.length === 0) {
            continue;
          }
          
          table = panel.elLk.tables.filter('.' + i).dataTable();
          
          panel.addDataTableRows(table, rows, true);
          
          panel.elLk.recordTypes.filter('.' + i).show();
          table.fnSort(panel.params.recordType === 'config' ? [[ 0, 'asc' ], [ 1, 'asc' ], [ 2, 'asc' ]] : [[ 0, 'asc' ]]);
          table.togglewrap('update');
        }
        
        panel.elLk.noRecords.hide();
        
        $.extend(panel.params.records, json.data);
        
        // TODO: updateSavedConfig - will be needed once you can save direct to a group (work out how existing saveAs options are added in Configurator)
        
        table = rows = null;
      }
    });
  },
  
  updateTable: function (data) {
    var record    = this.params.records[data.id];
    var rows      = this.elLk.editTable.find('tbody tr');
    var list      = this.elLk.tables.find('.' + data.id).find('.editables_list');
    var editables = list.first().children().detach();
    var added     = data.editables.added   || [];
    var removed   = data.editables.removed || [];
    var update, editable, i, j;
    
    // FIXME: because this is done in an AJAX callback, you can open another edit in the mean time which won't reflect the correct state wrt disabled rows
    for (i = 0; i < added.length; i++) {
      editable  = this.params.editables[added[i]];
      update    = this.params.recordType === 'config' ? [ editable, record ] : [ record, editable ];
      editables = editables.add($(this.params.listTemplate).addClass(added[i]).find('.name').html(editable.name).end().find('.conf').html(editable.conf).end());
      
      record.editables[added[i]] = 1;
      
      update[0].codes = update[0].codes.concat($.grep(update[1].codes, function (v) { return $.inArray(v, update[0].codes) === -1; }));
    }
    
    for (i = 0; i < removed.length; i++) {
      editable  = this.params.editables[removed[i]];
      update    = this.params.recordType === 'config' ? [ editable, record ] : [ record, editable ];
      editables = editables.not('.' + removed[i]);
      
      delete record.editables[removed[i]];
      
      for (j in update[1].codes) {
        update[0].codes = $.grep(update[0].codes, function (v) { return v !== update[1].codes[j]; }); 
      }
    }
    
    // Add/remove config code class on set rows so that we know which rows to be disabled (sets cannot contain two configs of the same code)
    if (this.params.recordType === 'config') {
      rows.filter('.' + (added.join(', .')   || '_')).addClass(record.codes[0]);
      rows.filter('.' + (removed.join(', .') || '_')).removeClass(record.codes[0]);
    }
    
    // Schwartzian transform - sort on lower case text of the entries
    list.html(editables.map(function () {
      return [[ $(this).text().toLowerCase(), this ]];
    }).sort(function (a, b) { return a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0; }).map(function () {
      return this[1];
    })).parent()[editables.length ? 'show' : 'hide']().siblings('.none')[editables.length ? 'hide' : 'show']().parents('td').togglewrap('update');
    
    rows = list = editables = null;
  },
  
  activateRecord: function (tr) {
    var data = this.params.records[tr.data('configId')];

    tr.siblings('.active').stop(true, true).removeClass('active').find('.config_used').stop(true, true).hide();
    tr.addClass('active').find('.config_used').show().delay(1000).fadeOut(500);

    this.updatePanels(data);
    
    if (data.codes.length) {
      this.elLk.resetAll.show();
    }
    
    tr = null;
  },  
  
  saveRecord: function (tr, json) {
    var session      = this.elLk.editTypes.filter('.session');
    var user         = this.elLk.editTypes.filter('.user');
    var sessionTable = session.find('table').dataTable();
    var userTable    = user.find('table').dataTable();
    var saved        = $('<span class="icon_link sprite sprite_disabled _ht save_icon" title="Saved">&nbsp;</span>').helptip();
    
    this.elLk.tables.find('tr').filter('.' + json.ids.join(', .')).find('a.save_icon').replaceWith(saved);
    
    var rows = sessionTable.find('tr').filter('.' + json.ids.join(', .'));
    
    this.addDataTableRows(userTable, rows);
    
    rows.each(function () { sessionTable.fnDeleteRow(this); });
    
    userTable.fnSort(this.params.recordType === 'set' ? [[ 0, 'asc' ], [ 1, 'asc' ], [ 2, 'asc' ]] : [[ 0, 'asc' ]]);
    userTable.togglewrap('update');
    
    for (var i in json.ids) {
      if (this.params.records[json.ids[i]]) {
        this.params.records[json.ids[i]].group   = 'user';
        this.params.records[json.ids[i]].groupId = this.params.userId;
      }
    }
    
    tr = rows = session = user = sessionTable = userTable = saved = null;
  },
  
  saveAll: function (tr, json) {
    var lists = { sets: '', configs: '' };
    var j;
    
    json.sets    = (json.sets    || []).sort();
    json.configs = (json.configs || []).sort();
    
    for (var i in lists) {
      for (j in json[i]) {
        lists[i] += '<li>' + json[i][j] + '</li>';
      }
      
      this.elLk[i === 'sets' ? 'saveSets' : 'saveConfigs'].html(lists[i]).parent()[lists[i] ? 'show' : 'hide']();
    }
    
    this.elLk.saveHeader.html(this.params.records[tr.data('configId')].name);
    this.elLk.saveAllLink = tr.find('a.save_all');
    
    Ensembl.EventManager.trigger('modalOverlayShow', this.elLk.saveAll);
    
    tr = null;
  },
  
  deleteRecord: function (tr) {
    var table = tr.parents('table');
    
    table.dataTable().fnDeleteRow(tr[0]);
    
    if (table.find('.dataTables_empty').length) {
      if (!table.parents('.record_type').hide().siblings('.record_type').filter(':visible').length) {
        this.elLk.noRecords.show();
      }
    }
    
    Ensembl.EventManager.trigger('updateSavedConfig', { deleted: [ tr.data('configId') ] });
    
    table = tr = null;
  },
  
  updatePanels: function (data) {
    var component;
    
    for (var i in data.codes) {
      component = data.codes[i].split('_')[1];
      
      if (Ensembl.PanelManager.panels[component]) {
        Ensembl.EventManager.trigger('queuePageReload', component, true);
        Ensembl.EventManager.trigger('activateConfig',  component);
      }
    }
  },
  
  addDataTableRows: function (table, rows, hasData) {
    var cells   = rows.first().children();
    var indexes = table.fnAddData(rows.map(function () { return $(this).children().map(function () { return this.innerHTML; }); }).toArray());
    var rowData = table.fnSettings().aoData;
    var i       = indexes.length;
    
    while (i--) {
      $(rowData[indexes[i]].nTr).addClass(rows[i].className).children().addClass(function (j) { return cells[j].className; }).find('._ht').helptip();
      
      if (hasData) {
        $(rowData[indexes[i]].nTr).data('configId', rows[i].className);
      }
    }
    
    table = rows = cells = null;
  },
  
  // Config view: Editing configs in a set - updateTable, sharing - addTableRow
  // Set view:    Editing configs in a set - updateTable, sharing - addTableRow, creating a new set - addTableRow
  formSubmit: function (form) {
    $.ajax({
      url: form.attr('action'),
      type: form.attr('method'),
      data: form.serialize(),
      traditional: true,
      cache: false,
      dataType: 'json',
      context: this,
      success: function (json) {
        if (this[json.func]) {
          this[json.func](json);
        }
      }
    });
    
    return false;
  }
});
