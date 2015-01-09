/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

Ensembl.DataTable = {
  dataTableInit: function () {
    var panel = this;
    
    this.elLk.dataTable.each(function () {
      // Because dataTables is written to create alert messages if you try to reinitialise a table, block any attempts here.
      for (var i in $.fn.dataTableSettings) {
        if ($.fn.dataTableSettings[i].nTable === this) {
          return;
        }
      }
      
      var table      = $(this);
      var noToggle   = table.hasClass('no_col_toggle');
      var exportable = table.hasClass('exportable');
      var options    = panel.getOptions(table, noToggle, exportable);
      
      $.fn.dataTableExt.oStdClasses.sWrapper = table.hasClass('toggle_table') ? 'toggleable toggleTable_wrapper' : 'dataTables_wrapper';
      
      var dataTable = table.dataTable(options);
      var settings  = dataTable.fnSettings();
      
      $('.dataTables_filter input', settings.nTableWrapper).after('<div class="overlay">Filter</div>').on({
        focus: function () {
          $(this).siblings('.overlay').hide();
        },
        blur: function () {
          if (!this.value) {
            $(this).siblings('.overlay').show();
          }
        }
      });
      
      if (!noToggle) {
        panel.columnToggle(settings);
      }
      
      if (exportable) {
        panel.makeExportable(settings.nTableWrapper);
      }
      
      if (table.hasClass('editable')) {
        panel.makeEditable(table);
      }
              
      panel.dataTables = panel.dataTables || [];
      panel.dataTables.push(dataTable);

      table = dataTable = null;
    });
    
    this.elLk.colToggle = $('.col_toggle', this.el);
    
    this.tableFilters();
  },
  
  getOptions: function (table, noToggle, exportable) {
    var length     = $('tbody tr', table).length;
    var noSort     = table.hasClass('no_sort');
    var menu       = [[], []];
    var options    = {
      sPaginationType: 'full_numbers',
      aaSorting:       [],
      aoColumnDefs:    [],
      asStripClasses:  [ 'bg1', 'bg2' ],
      iDisplayLength:  -1,
      bAutoWidth:      false,
      oLanguage: {
        sSearch:   '',
        oPaginate: {
          sFirst:    '&lt;&lt;',
          sPrevious: '&lt;',
          sNext:     '&gt;',
          sLast:     '&gt;&gt;'
        }
      },
      fnInitComplete: function () {
        var hidden = this.is(':hidden');
        var parent = this.parent();
        var hide   = this.css('display') === 'none';
        
        if (this[0].style.width !== '100%') {
          if (hidden) {
            this.show(); // show table momentarily (not noticable in the browser) so that width is correct
          }
          
          parent.width(this.outerWidth());
        }
        
        if (hidden && hide) {
          parent.hide(); // Hide the wrapper of already hidden table
          this.removeClass('hide');
        }
        
        parent = null;
      },
      fnDrawCallback: function (tableSettings) {
        $('.dataTables_info, .dataTables_paginate, .dataTables_bottom', tableSettings.nTableWrapper)[tableSettings._iDisplayLength === -1 ? 'hide' : 'show']();
        
        var data          = this.data();
        var defaultHidden = data.defaultHiddenColumns || [];
        var hiddenCols    = $.map(tableSettings.aoColumns, function (c, j) { return c.bVisible ^ defaultHidden[j] ? null : j * (defaultHidden[j] ? -1 : 1); }).join(',');
        var sorting       = $.map(tableSettings.aaSorting, function (s) { return '"' + s.join(' ') + '"'; }).join(',');
        
        if (tableSettings._bInitComplete !== true) {
          this.data({ hiddenCols: hiddenCols, sorting: sorting });
          return;
        }
        
        this.fnSettings().oInit.fnInitComplete.call(this);
        this.data('export', false);
        
        for (var i = 0; i < tableSettings.aoOpenRows.length; i++) {
          tableSettings.aoOpenRows[i].nTr.className = tableSettings.aoOpenRows[i].nParent.className;
        }
        
        if (data.hiddenCols !== hiddenCols || data.sorting !== sorting) {
          this.data({ hiddenCols: hiddenCols, sorting: sorting });
          
          $.ajax({
            url: '/Ajax/data_table_config',
            data: {
              id:             this.data('code'),
              sorting:        sorting,
              hidden_columns: hiddenCols
            }
          });
        }
        
        Ensembl.EventManager.trigger('dataTableRedraw');
      }
    };
    
    options.aoColumns = $('thead th', table).map(function () {
      var sort = this.className.match(/\s*sort_(\w+)\s*/);
      var rtn  = {};
      
      sort = sort ? sort[1] : 'string';
      
      if (noSort || sort === 'none') {
        rtn.bSortable = false;
      } else {
        rtn.sType = $.fn.dataTableExt.oSort[sort + '-asc'] ? sort : 'string';
      }
      
      return rtn;
    }).toArray();
    
    if (length > 10) {
      options.sDom = '<"dataTables_top"l' + (noToggle ? '' : '<"col_toggle">') + (exportable ? '<"dataTables_export">' : '') + 'f<"invisible">>t<"dataTables_bottom"ip<"invisible">>';
      
      $.each([ 10, 25, 50, 100 ], function () {
        if (this < length) {
          menu[0].push(this);
          menu[1].push(this);
        }
      });
      
      menu[0].push(-1);
      menu[1].push('All');
    } else {
      options.sDom = '<"dataTables_top"' + (noToggle ? '' : '<"col_toggle left">') + (exportable ? '<"dataTables_export">' : '') + '<"dataTables_filter_overlay">f<"invisible">>t';
    }
    
    options.aLengthMenu = menu;
    
    // Extend options from config defined in the html
    $('input', table.siblings('form.data_table_config')).each(function () {
      if (this.name === 'code') {
        table.data('code', this.value);
        
        return;
      }
      
      var val = JSON.parse(this.value.replace(/'/g, '"'));
      
      if (this.name === 'hiddenColumns') {
        $.each(val, function () {
          if (options.aoColumns[this]) {
            options.aoColumns[this].bVisible = false;
          }
        });
      } else if (this.name.indexOf('expopts') === 0) {
        // no-op, this isn't an option for the client side
      } else if (typeof options[this.name] === 'object') {
        $.extend(true, options[this.name], val);
      } else {
        options[this.name] = val;
      }
    });
    
    if (options.defaultHiddenColumns) {
      table.data('defaultHiddenColumns', options.defaultHiddenColumns);
      delete options.defaultHiddenColumns;
    }
    
    table = null;
    
    return options;
  },

  buttonText: function(settings) {
    var columns = settings.aoColumns;
    var hidden = 0;
    $.each(columns,function(col) {
      if(!columns[col].bVisible) {
        hidden++;
      }
    });
    var hidden_txt = '';
    if(hidden) {
      hidden_txt = ' ('+hidden+' hidden)';
    }
    return 'Show/hide columns'+hidden_txt;
  },

  columnToggle: function (settings) {
    var panel = this;
    
    var columns    = settings.aoColumns;
    var toggleList = $('<ul class="floating_popup"></ul>');

    var toggle     = $('<div class="toggle">'+panel.buttonText(settings)+'</div>').append(toggleList).on('click', function (e) { if (e.target === this) { toggleList.toggle(); if(toggleList.is(':hidden')) { toggle.remove(); panel.columnToggle(settings); }  } });
    
    $.each(columns, function (col) {
      var th = $(this.nTh);
      
      $('<li>', {
        html: '<input data-role="none" type="checkbox"' + (th.hasClass('no_hide') ? ' disabled' : '') + (columns[col].bVisible ? ' checked' : '') + ' /><span>' + th.text() + '</span>',
        click: function () {
          var input  = $('input', this);
          var tables, visibility, index, textCheck;
          
          if (!input.prop('disabled')) {
            tables     = $.grep(panel.dataTables, function (table) { return !table.is('.no_col_toggle'); });
            visibility = !columns[col].bVisible;
            
            if (panel.elLk.colToggle.length === 1) {
              input.prop('checked', visibility);
            } else {
              index     = $(this).index();
              textCheck = $(this).parent().text();
              tables    = [];
              
              panel.elLk.colToggle.each(function (i) {
                if ($(this).find('ul').text() === textCheck) {
                  $('input', this).get(index).checked = visibility;
                  tables.push(panel.dataTables[i]);
                }
              });
            }
            $.each(tables, function () {
              this.fnSetColumnVis(col, visibility);
            });
          }
        
          input = null;
        }
      }).appendTo(toggleList);
      
      th = null; 
    });
    
    $('.col_toggle', settings.nTableWrapper).append(toggle);
  },
  
  makeExportable: function (wrapper) {
    function exportHover() {
      $(this).children().toggle();
      
      if (Ensembl.browser.ie67) {
        $(this).siblings('.dataTables_filter').toggle();
      }
    }
    
    $('.dataTables_top .dataTables_export', wrapper).append(
      '<div class="floating_popup"><a>Download what you see</a><a class="all">Download whole table</a></div>'
    ).hoverIntent({
      over:     exportHover,
      out:      exportHover,
      interval: 300
    }).on('click', function (e) {
      var table    = $(this).parent().next();
      var settings = table.dataTable().fnSettings();
      var form     = $(settings.nTableWrapper).siblings('form.data_table_export');
      var data;
      
      if (e.target.className === 'all') {
        if (!table.data('exportAll')) {
          data = [[]];
          
          $.each(settings.aoColumns, function (i, col) { data[0].push(col.sTitle); });
          $.each(settings.aoData,    function (i, row) { data.push(row._aData);    });

          table.data('exportAll', data);
          form.find('input.data').val(JSON.stringify(data));
        }
      } else {
        if (!table.data('export')) {
          data = [];
          
          $('tr', table).each(function (i) {
            data[i] = [];
            
            $(this.cells).each(function () {
              var hidden = $('.hidden:not(.export)', this);
              
              if (hidden.length) {
                data[i].push($.trim($(this).clone().find(hidden).remove().end().html()));
              } else {
                data[i].push($(this).html());
              }
              
              hidden = null;
            });
          });
          
          table.data('export', data);
          form.find('input.data').val(JSON.stringify(data));
        }
      }
      
      form.trigger('submit');
      
      table = form = null;
    });
    
    wrapper = null;
  },
  
  makeEditable: function (table) {
    var panel = this;
    
    function saveEdit(input) {
      if (input.is(':hidden')) {
        input = null;
        return false;
      }
      
      var td    = input.parents('td');
      var value = input.hide().val().replace(/<[^>]+>/g, ''); // strip HTML tags
      var name  = input.attr('name');
      
      input.siblings().show();
      
      if (input.data('oldVal') !== value) {
        input.data('oldVal', value);
        input.parent().find('.val').html(value.replace(/\n/g, '<br />'));
        input.parents('table').dataTable().fnUpdate(td.html(), td.parent()[0], td.index());
        
        if (typeof panel.saveEdit === 'function') {
          panel.saveEdit(name, value, td);
        } else {
          $.ajax({
            url: td.find('a.save').attr('href'),
            data: { param: name, value: value },
            success: function (response) {
              if (response === 'reload') {
                if (panel instanceof Ensembl.Panel.ModalContent) {
                  panel.el.append('<div class="modal_reload"></div>');
                } else {
                  Ensembl.EventManager.trigger('queuePageReload', '', false, false);
                }
              }
            }
          });
        }
      }
      
      input = td = null;
    }
    
    table.on('click', '.editable', function (e) {
      if ($(e.target).is('.val')) {
        $(this).find(':input').val(
          $(this).find('.val').html().replace(/\n/g, '').replace(/<br( \/)?>/g, '\n').replace(/<[^>]+>/g, '')
        ).show().trigger('focus').siblings().hide();
      }
    }).on({
      blur:    function ()  { saveEdit($(this));                                          },
      keydown: function (e) { if (e.keyCode === 13 && !e.shiftKey) { return false;      } },
      keyup:   function (e) { if (e.keyCode === 13 && !e.shiftKey) { saveEdit($(this)); } }
    }, '.editable :input');
    
    table = null;
  },
  
  // Data tables can be controlled by external filters - checkboxes with values matching classnames on table rows
  // Selecting checkboxes will show only rows matching those values
  tableFilters: function () {
    var panel   = this;
    var filters = $('input.table_filter', this.el);
    
    if (!filters.length) {
      return;
    }
    
    $.fn.dataTableExt.afnFiltering.push(
      function (settings, aData, index) {
        var i, className;
        
        if (settings.classFilter) {
          i         = settings.classFilter.length;
          className = ' ' + settings.aoData[index].nTr.className + ' ';
          
          while (i--) {
            if (className.indexOf(settings.classFilter[i]) !== -1) {
              return true;
            }
          }
          
          return false;
        }
        
        return true;
      }
    );
    
    filters.on('click', function () {
      var classNames = [];
      var dataTable  = $('#' + this.name, panel.el).dataTable();
      var settings   = dataTable.fnSettings();
      
      $('input.table_filter[name=' + this.name + ']', panel.el).each(function () {
        if (this.checked) {
          classNames.push(' ' + this.value + ' ');
        }
      });
      
      if (classNames.length) {
        settings.classFilter = classNames;
      } else {
        delete settings.classFilter;
      }
      
      dataTable.fnFilter($('.dataTables_filter input', settings.nTableWrapper).val());
      
      dataTable = null;
    });
    
    filters = null;
  }
};
