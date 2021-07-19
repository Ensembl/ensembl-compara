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
      
      var filterInput   = $('.dataTables_filter input', settings.nTableWrapper);
      var filterOverlay = filterInput.after('<div class="overlay">Filter</div>').on({
        focus: function () {
          $(this).siblings('.overlay').hide();
        },
        blur: function () {
          if (!this.value) {
            $(this).siblings('.overlay').show();
          }
        }
      });
      if (filterInput.val() && filterInput.val().length) filterOverlay.siblings('.overlay').hide();

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
    var self = this;
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
      fnInitComplete: function (oSettings) {
        var hidden = this.is(':hidden');
        var parent = this.closest('.toggleTable_wrapper, .dataTables_wrapper');
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
        self.makeHeaderSticky(oSettings && oSettings.oInstance && oSettings.oInstance[0]);
      },
      fnDrawCallback: function (tableSettings) {
        this.togglewrap('redo');
        $('.dataTables_info, .dataTables_paginate, .dataTables_bottom', tableSettings.nTableWrapper)[tableSettings._iDisplayLength === -1 ? 'hide' : 'show']();
        
        var data          = this.data();
        var hiddenCols = tableSettings.aoColumns.reduce(function (accumulator, column, index) {
          return !column.bVisible ? accumulator.concat(index) : accumulator;
        }, []).join(','); // gets a string of comma-separated indices of hidden columns
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
    $('input', table.siblings('div.data_table_config')).each(function () {
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
      var column_heading = $(th).clone().find('.hidden').remove().end().html();
      $('<li>', {
        html: '<input data-role="none" type="checkbox"' + (th.hasClass('no_hide') ? ' disabled' : '') + (columns[col].bVisible ? ' checked' : '') + ' /><span>' + column_heading + '</span>',
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
    ).hover(exportHover, exportHover).on('click', function (e) {
      var table    = $(this).parent().next();
      var settings = table.dataTable().fnSettings();
      var form     = $(settings.nTableWrapper).siblings('form.data_table_export');
      var data;

      if (e.target.className === 'all') {
        if (!table.data('exportAll')) {
          data = [[]];
          var col_index_for_no_export = [];
          // For column heading
          $.each(settings.aoColumns, function (i, col) { 
            var no_export = $(col.nTh).hasClass('_no_export');
            if (!no_export) {
              var div = $( "<div/>" );
              div.append(col.sTitle);
              var hidden = $('.hidden:not(.export)', $(div));
              if (hidden.length) {
                data[0].push($.trim($(div).find(hidden).remove().end().html()));
              }
              else {
                data[0].push(col.sTitle);
              }
            }
            else {
              // Storing column indexes to handle _no_export
              col_index_for_no_export.push(i)
            }
          });
          // For column data
          $.each(settings.aoData, function (i, row) { 
            var t_arr = [];
            $(row._aData).each(function (j, cellVal) {
              // Putting inside a div so that the jquery selector works for all
              //  "hidden" elements inside the div
              var div = $( "<div/>" );
              div.append(cellVal);
              if ($.inArray(j, col_index_for_no_export) == -1) {
                var hidden = $('.hidden:not(.export), ._no_export', $(div));
                if (hidden.length) {
                  t_arr.push($.trim($(div).find(hidden).remove().end().html()));
                } else {
                  t_arr.push(cellVal);
                }
              }
            });
            data.push(t_arr);
          });

          table.data('exportAll', data);
          form.find('input.data').val(JSON.stringify(data));
        }
      } else {        
        if (!table.data('export')) {
          var tableClone = table.clone();
          data = [];
          // Remove all hidden and _no_export classes from the clone.
          $(tableClone).find('.hidden:not(.export), ._no_export').remove();
          // Traversing through each displayed row for downloading what you see 
          $('tr', tableClone).each(function (i) {
            data[i] = [];            
            $(this.cells).each(function () {
              data[i].push($(this).html());
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

      if (this.checked) {
        if (this.value === 'all') {
          // if all checkbox gets selected then unselect all the other checkboxes
          $('input.table_filter[name=' + this.name + ']', panel.el).not('[value=all]', panel.el).prop('checked', false);
        } else {
          // if a checkbox is selected while all is already selected then unselect all
          if ($('input.table_filter[name=' + this.name + '][value=all]', panel.el).prop('checked') === true) {
            $('input.table_filter[name=' + this.name + '][value=all]', panel.el).prop('checked', false);
          }

          var checkboxCount = $('input.table_filter[name=' + this.name + ']', panel.el).length;

          // if all checkboxes are selected (with or without all) then select only all
          if ($('input.table_filter[name=' + this.name + ']:checked', panel.el).length >= (checkboxCount - 1)) {
            $('input.table_filter[name=' + this.name + ']:checked', panel.el).prop('checked', false);
            $('input.table_filter[name=' + this.name + '][value=all]', panel.el).prop('checked', true);
          };
        }
      } else {
        // if all checkboxes are unselected then select all
        if ($('input.table_filter[name=' + this.name + ']:checked', panel.el).length === 0) {
          $('input.table_filter[name=' + this.name + '][value=all]', panel.el).prop('checked', true);
        }
      }
  
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

      Ensembl.EventManager.trigger('dataTableFilterUpdated', classNames);
    });

    filters = null;
  },

  makeHeaderSticky: function (table) {
    if (!table || this.headerIsSticky) {
      return;
    }

    if (table.offsetHeight > window.innerHeight) {
      new StickyHeader(table);
      this.headerIsSticky = true;
    }
  }
};



function StickyHeader (table) {
  this.table = table;
  this.tableHead = table.querySelector('thead');
  this.tableBody = table.querySelector('tbody');

  this.scrollHandler = this.syncHeadScroll.bind(this);

  this.observeBody();
  this.handleWindowResize();
};

StickyHeader.prototype.constructor = StickyHeader;

StickyHeader.prototype.observeBody = function () {
  window.addEventListener('scroll', function () {
    window.requestAnimationFrame(function () {
      if (this.shouldStickHead()) {
        this.stickHead();
      } else {
        this.unstickHead();
      }
    }.bind(this));
  }.bind(this));
};

StickyHeader.prototype.handleWindowResize = function () {
  window.addEventListener('resize', function () {
    window.requestAnimationFrame(function () {
      if (this.shouldStickHead()) {
        this.unstickHead();
        this.stickHead();
      } else {
        this.unstickHead();
      }
    }.bind(this));
  }.bind(this));
};

StickyHeader.prototype.shouldStickHead = function () {
  var tableBodyBoundingRect = this.tableBody.getBoundingClientRect();
  var tableBodyTop = tableBodyBoundingRect.top;
  var tableBodyBottom = tableBodyBoundingRect.bottom;
  return tableBodyTop < 0 && tableBodyBottom - this.tableHead.offsetHeight > 0;
};

StickyHeader.prototype.buildStickyHeaderContainer = function () {
  var container = document.createElement('div');
  var wrapperDimensions = this.getDimensionsForStickyHeaderContainer();
  container.style.position = 'fixed';
  container.style.top = '0';
  container.style.left = wrapperDimensions.left;
  container.style.width = wrapperDimensions.width;
  container.style.overflow = 'hidden';
  return container;
};

StickyHeader.prototype.getDimensionsForStickyHeaderContainer = function () {
  // sometimes a wide table can be placed inside a horizontally scrollable container,
  // to whose width and scroll position the sticky header will have to adjust
  var nearestScrollableWrapper = $(this.table)
    .parents('div')
    .filter(function (index, element) {
      var computedStyles = window.getComputedStyle(element);
      return computedStyles.getPropertyValue('overflow-x') === 'auto';
    })[0];
  var wrapperBoundingRect = nearestScrollableWrapper && nearestScrollableWrapper.getBoundingClientRect();
  var tableBoundingRect = this.table.getBoundingClientRect();
  var useScrollableWrapper = wrapperBoundingRect && wrapperBoundingRect.width < tableBoundingRect.width;

  if (useScrollableWrapper) {
    this.scrollableWrapper = nearestScrollableWrapper;
  }

  var refetenceRect = useScrollableWrapper ? wrapperBoundingRect : tableBoundingRect;

  return {
    left: refetenceRect.left + 'px',
    width: refetenceRect.width + 'px'
  }
};

StickyHeader.prototype.stickHead = function () {
  if (this.isHeaderStuck) return;

  // before changing thead styles, create a duplicate of thead that will occupy its place
  // while the original thead will be removed from normal layout flow into the fixed position
  this.tweenTableHead = this.tableHead.cloneNode(true);
  var initialHeaderWidth = this.tableHead.offsetWidth;
  this.table.insertBefore(this.tweenTableHead, this.tableHead);

  this.container = this.container || this.buildStickyHeaderContainer();
  this.tableHead.style.width = initialHeaderWidth + 'px';
  this.tableHead.style.display = 'table';
  this.tableHead.querySelector('tr').style.whiteSpace = 'nowrap';
  this.tableHead.querySelector('tr').style.display = 'table';
  this.tableHead.querySelector('tr').style.width = '100%';
  this.table.removeChild(this.tableHead);
  this.table.insertBefore(this.container, this.tableBody);
  this.container.appendChild(this.tableHead);
  
  this.setColumnWidths();
  
  this.handleTableScroll();
  this.isHeaderStuck = true;
};

StickyHeader.prototype.handleTableScroll = function () {
  if (!this.scrollableWrapper) {
    return;
  }
  this.syncHeadScroll();
  this.scrollableWrapper.addEventListener('scroll', this.scrollHandler);
};

StickyHeader.prototype.syncHeadScroll = function () {
  var tableParent = this.table.parentElement;
  var offsetLeft = tableParent.scrollLeft;
  this.container.scrollLeft = offsetLeft;
};

StickyHeader.prototype.setColumnWidths = function () {
  var headColumns = Array.prototype.slice.call(this.tableHead.querySelectorAll('th'));
  var referenceColumns = Array.prototype.slice.call(this.tweenTableHead.querySelectorAll('th'));
  var shouldAddWidths = headColumns.every(function (element) { return !element.style.width });
  if (shouldAddWidths) {
    headColumns.forEach(function (headColumn, index) {
      var column = referenceColumns[index];
      var columnWidth = column.offsetWidth;
      var computedStyles = window.getComputedStyle(column);
      headColumn.style.boxSizing = 'border-box';
      headColumn.style.display = 'inline-block';
      headColumn.style.width = columnWidth + 'px';
      headColumn.style.whiteSpace = computedStyles.getPropertyValue('white-space') === 'nowrap' ? 'nowrap' : 'normal';
    });
    this.areColumnWidthsSet = true;
  }
};

StickyHeader.prototype.unsetColumnWidths = function () {
  if (!this.areColumnWidthsSet) return;
  var headColumns = Array.prototype.slice.call(this.tableHead.querySelectorAll('th'));
  headColumns.forEach(function (headColumn) {
    headColumn.style.removeProperty('box-sizing');
    headColumn.style.removeProperty('display');
    headColumn.style.removeProperty('width');
  });
  this.areColumnWidthsSet = false;
};


StickyHeader.prototype.unstickHead = function () {
  if (this.isHeaderStuck) {
    this.table.removeChild(this.tweenTableHead);
    this.table.insertBefore(this.tableHead, this.tableBody);
    this.tableHead.style.removeProperty('width');
    this.tableHead.style.removeProperty('display');
    this.tableHead.querySelector('tr').style.removeProperty('display');
    this.unsetColumnWidths();
    this.table.removeChild(this.container);
    this.container = null;
    this.isHeaderStuck = false;

    var tableParent = this.table.parentElement;
    tableParent.removeEventListener('scroll', this.scrollHandler);
  }
};
