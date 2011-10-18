// $Revision$

Ensembl.DataTable = {
  dataTableInit: function () {
    var panel = this;
    
    this.hideFilter = $('body').hasClass('ie67');
    
    this.elLk.dataTable.each(function (i) {
      // Because dataTables is written to create alert messages if you try to reinitialise a table, block any attempts here.
      if ($.fn.dataTableSettings[i] && $.fn.dataTableSettings[i].nTable === this) {
        return;
      }
      
      var table      = $(this);
      var noToggle   = table.hasClass('no_col_toggle');
      var exportable = table.hasClass('exportable');
      var options    = panel.getOptions(table, noToggle, exportable);
      
      $.fn.dataTableExt.oStdClasses.sWrapper = table.hasClass('toggle_table') ? 'toggleable toggleTable_wrapper' : 'dataTables_wrapper';
      
      var dataTable = table.dataTable(options);
      var settings  = dataTable.fnSettings();
      
      $('.dataTables_filter input', settings.nTableWrapper).after('<div class="overlay">Filter</div>').bind({
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
      
      panel.dataTables = panel.dataTables || [];
      panel.dataTables.push(dataTable);
      
      table = dataTable = null;
    });
    
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
        if (this[0].style.width !== '100%') {
          if (this.not(':visible').length) {
            this.show(); // show table momentarily (not noticable in the browser) so that width is correct
            this.parent().width(this.outerWidth()).hide(); // Hide the wrapper of already hidden table
          } else {
            this.parent().width(this.outerWidth());
          }
        }
      },
      fnDrawCallback: function (data) {
        $('.dataTables_info, .dataTables_paginate, .dataTables_bottom', data.nTableWrapper)[data._iDisplayLength === -1 ? 'hide' : 'show']();
        
        if (data._bInitComplete !== true) {
          return;
        }
        
        this.data('export', false);
        
        var sorting = $.map(data.aaSorting, function (s) { return '"' + s.join(' ') + '"'; }).join(',');
        var hidden  = $.map(data.aoColumns, function (c, j) { return c.bVisible ? null : j; }).join(',');
        
        $.ajax({
          url: '/Ajax/data_table_config',
          data: {
            id:             this.data('code'),
            sorting:        sorting,
            hidden_columns: hidden
          }
        });
        
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
    });
    
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
          options.aoColumns[this].bVisible = false;
        });
      } else if (typeof options[this.name] === 'object') {
        $.extend(true, options[this.name], val);
      } else {
        options[this.name] = val;
      }
    });
    
    table = null;
    
    return options;
  },
  
  columnToggle: function (settings) {
    var panel = this;
    
    var columns    = settings.aoColumns;
    var toggleList = $('<ul class="floating_popup"></ul>');
    var toggle     = $('<div class="toggle">Show/hide columns</div>').append(toggleList).bind('click', function (e) { if (e.target === this) { toggleList.toggle(); } });
    
    this.elLk.colToggle = $('.col_toggle', this.el);
    
    $.each(columns, function (col) {
      var th = $(this.nTh);
      
      $('<li>', {
        html: '<input type="checkbox"' + (th.hasClass('no_hide') ? ' disabled' : '') + (columns[col].bVisible ? ' checked' : '') + ' /><span>' + th.text() + '</span>',
        click: function () {
          var input  = $('input', this);
          var tables, visibility, index, textCheck;
          
          if (!input.attr('disabled')) {
            tables     = panel.dataTables;
            visibility = !columns[col].bVisible;
            
            if (panel.elLk.colToggle.length === 1) {
              input.attr('checked', visibility);
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
    var panel = this;
    
    function exportHover() {
      $(this).children().toggle();
      
      if (panel.hideFilter) {
        $(this).siblings('.dataTables_filter').toggle();
      }
    }
    
    $('.dataTables_top .dataTables_export', wrapper).append(
      '<div class="floating_popup"><a>Download what you see</a><a class="all">Download whole table</a></div>'
    ).hoverIntent({
      over:     exportHover,
      out:      exportHover,
      interval: 300
    }).bind('click', function (e) {
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
              var hidden = $('.hidden', this);
              
              if (hidden.length) {
                data[i].push($.trim($(this).clone().find('.hidden').remove().end().html()));
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
    
    filters.bind('click', function () {
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
