// $Revision$

Ensembl.Panel.Content = Ensembl.Panel.extend({
  init: function () {    
    this.base();
    this.ajaxLoad();
    
    this.hideHints();
    this.toggleTable();
    this.toggleList();
    this.dataTable();
    
    Ensembl.EventManager.register('updatePanel', this, this.getContent);
    Ensembl.EventManager.trigger('validateForms', this.el);
    Ensembl.EventManager.trigger('relocateTools', $('.other-tool', this.el));
    
    // Links in a popup (help) window should make a new window in the main browser
    if (window.name.match(/^popup_/)) {
      $('a', this.el).click(function () {
        window.open(this.href, window.name.replace(/^popup_/, '') + '_1');
        return false;
      });
    }
    
    $('.glossary_mouseover', this.el).bind({
      mouseover: function () {
        var el = $(this);
        var popup = el.children('.floating_popup');
        
        var position = el.position();
        position.top  -= popup.height() - (0.25 * el.height());
        position.left += 0.75 * el.width();
        
        popup.show().css(position);
        popup = null;
        el = null;
      },
      mouseout: function () {
        $(this).children('.floating_popup').hide();
      }
    });
  },
  
  ajaxLoad: function () {
    var myself = this;
    var ajax = $('.ajax', this.el);
    
    if ($(this.el).hasClass('ajax')) {
      $.extend(ajax, $(this.el));
    }    
    
    $('.navbar', this.el).width(Ensembl.width);
    
    ajax.each(function () {
      var el = $(this);
      var urls = [];
      var content, caption, component;
      
      $('input.ajax_load', this).each(function () {
        urls.push(this.value);
      });
      
      if (!urls.length) {
        return;
      }
      
      if (urls[0].substr(0, 1) != '/') {
        caption = urls.shift();
        
        content = $('<div class="content"></div>');
        
        el.append('<h4>' + caption + '</h4>').append(content);
      } else {
        content = el;
      }
      
      for (var i = 0; i < urls.length; i++) {
        component = urls[i];
        
        if (component.substr(0, 1) == '/') {
          if (component.match(/\?/)) {
            var referer = '';
            var url = [];
            var params = component.split(/;/);
            var j = params.length;
            
            while (j--) {
              if (params[j].match(/^_referer=/)){
                referer = params[j];
              } else {
                url.unshift(params[j]);
              }
            }
            
            component = Ensembl.replaceTimestamp(url.join(';')) + referer;
          }
          
          myself.getContent(component, content, { updateURL: component + ';update_panel=1' });
        }
      }
      
      el = null;
      content = null;
    });
    
    ajax = null;
  },
  
  getContent: function (url, el, params) {
    var node;
    
    params = params || this.params;
    url = url || params.updateURL;
    el  = el  || $(this.el).empty();
    
    switch (el.attr('nodeName')) {
      case 'DL': node = 'dt'; break;
      case 'UL': 
      case 'OL': node = 'li'; break;
      default  : node = 'p';  break;
    }
    
    el.append('<' + node + ' class="spinner">Loading component</' + node + '>');
    
    Ensembl.EventManager.trigger('hideZMenu', this.id); // Hide ZMenus based on this panel
    
    $.ajax({
      url: url,
      dataType: 'html',
      success: function (html) {
        if (html) {
          var type = $(html).find('input.panel_type').val() || 'Content';
          Ensembl.EventManager.trigger('addPanel', undefined, type, html, el, params);
          Ensembl.EventManager.trigger('ajaxLoaded');
        } else {
          el.html('');
        }
      },
      error: function (e) {
        el.html('<p class="ajax_error">Failure: the resource "' + url + '" failed to load</p>');
      },
      complete: function () {
        el = null;
      }
    });
  },
  
  hideHints: function () {
    $('.hint', this.el).each(function () {
      var div = $(this);
      
      $('<img src="/i/close.gif" alt="Hide hint panel" title="Hide hint panel" />').click(function () {
        var tmp = [];
        
        div.hide();
        
        Ensembl.hideHints[div.attr('id')] = 1;
        
        for (var i in Ensembl.hideHints) {
          tmp.push(i);
        }
        
        Ensembl.cookie.set('ENSEMBL_HINTS', tmp.join(':'));
      }).prependTo(this.firstChild);
    });
  },
  
  toggleTable: function () {    
    var table = $('.toggle_table', this.el);
    
    if (table.length) {
      var id     = table.attr('id');
      var button = $('.toggle_button', this.el);
      var icon   = button.children('em').show();
      var info   = button.siblings('.toggle_info');
    
      button.click(function () {
        table.toggle().parent('.toggleTable_wrapper').toggle();
        info.toggle();
        icon.toggleClass('open closed');
        Ensembl.cookie.set('ENSEMBL_' + id, table.is(':visible') ? 'open' : 'close')
      });
      
      button = null;
    }
  },
  
  toggleList: function () {
    var attrs = {
      open: { src: '/i/list_open.gif', alt: 'V' },
      shut: { src: '/i/list_shut.gif', alt: '>' }
    };
    
    $('a.collapsible', this.el).click(function () {
      var img = $('img', this);
      
      img.attr(attrs[img.hasClass('open') ? 'shut' : 'open']).toggleClass('open');
      img = null;
      
      $(this).siblings('ul.shut').toggle();
      
      return false;
    });
  },
  
  dataTable: function () {
    var myself = this;
    
    $('table.data_table', this.el).each(function (i) {
      var table  = $(this);
      var length = $('tbody tr', this).length;
      var width  = table.hasClass('fixed_width') ? table.width() : '100%';
      var noSort = table.hasClass('no_sort');
      var menu   = '';
      var sDom;
      
      var cookieId      = this.id || 'data_table' + myself.panelNumber;
      var cookieName    = 'DT#' + (table.hasClass('toggle_table') ? '' : window.location.pathname.replace(Ensembl.speciesPath, '') + '#') + cookieId.replace(/^data_table/, '');
      var cookieOptions = Ensembl.cookie.get(cookieName, true);
      
      var cols = $('thead th', this).map(function () {
        var sort = this.className.match(/\s*sort_(\w+)\s*/);
        var rtn  = {};
        
        sort = sort ? sort[1] : 'string';
        
        if (noSort || sort == 'none') {
          rtn.bSortable = false;
        } else {
          rtn.sType = $.fn.dataTableExt.oSort[sort + '-asc'] ? sort : 'string';
        }
        
        return rtn;
      });
      
      if (length > 10) {
        sDom = '<"dataTables_top"l<"col_toggle">f<"invisible">>t<"dataTables_bottom"ip<"invisible">>';
        
        $.each([ 10, 25, 50, 100 ], function () {
          if (this < length) {
            menu += '<option value="' + this + '">' + this + '</option>';
          }
        });
        
        menu += '<option value="-1">All</option>';
      } else {
        sDom = '<"dataTables_top"<"col_toggle">f<"invisible">>t'
      }
      
      var options = {
        sPaginationType: 'full_numbers',
        aoColumns: cols,
        aaSorting: [],
        sDom: 't',
        asStripClasses: [ 'bg1', 'bg2' ],
        iDisplayLength: -1,
        bAutoWidth: false,
        oLanguage: {
          sLengthMenu: 'Show <select>' + menu + '</select> entries',
          sSearch: 'Search table:',
          oPaginate: {
            sFirst:    '<<',
            sPrevious: '<',
            sNext:     '>',
            sLast:     '>>'
          }
        },
        fnInitComplete: function () {
          table.width(width).parent().width(width);
          table.not(':visible').parent().hide(); // Hide the wrapper of already hidden tables
        },
        fnDrawCallback: function (data) {
          $('.dataTables_info, .dataTables_paginate', $(data.nTable).parent())[data._iDisplayLength == -1 ? 'hide' : 'show']();
          
          var sort   = $.map(data.aaSorting, function (s) { return '[' + s.toString().replace(/([a-z]+)/g, '"$1"') + ']'; });
          var hidden = $.map(data.aoColumns, function (c, j) { return c.bVisible ? null : j });
          
          Ensembl.cookie.set(cookieName, '[' + sort.join(',') + ']' + (hidden.length ? '#' + hidden.join(',') : ''), 1, true);
          
          Ensembl.EventManager.trigger('dataTableRedraw');
        }
      };
      
      // Extend options from config defined in the html
      $('input', table.siblings('form.data_table_config')).each(function () {
        options[this.name] = eval(this.value);
      });
      
      // Extend options from the cookie
      if (cookieOptions) {
        cookieOptions = cookieOptions.replace(/#$/, '').split('#');
        
        options.aaSorting = eval(cookieOptions[0]);
        
        if (cookieOptions[1]) {
          $.each(cookieOptions[1].split(','), function () {
            options.aoColumns[this].bVisible = false;
          });
        }
      }
      
      $.fn.dataTableExt.oStdClasses.sWrapper = table.hasClass('toggle_table') ? 'toggleTable_wrapper' : 'dataTables_wrapper';
      
      var dataTable = table.dataTable(options);
      
      myself.elLk.colToggle = $('.col_toggle', myself.el);
      
      var columns    = dataTable.fnSettings().aoColumns;
      var toggle     = $('<div class="toggle">Toggle columns</div>').click(function () { $(this).next().toggle(); });
      var toggleList = $('<ul class="floating_popup"></ul>');
      
      $.each(columns, function (col) {
        var th = $(this.nTh);
        
        $('<li>').click(function () {
          var input = $('input', this);
          
          if (!input.attr('disabled')) {
            var visibility = !columns[col].bVisible;
            
            if (myself.elLk.colToggle.length == 1) {
              input.attr('checked', visibility);
            } else {
              var index = input.index();
              
              myself.elLk.colToggle.each(function () {
                $('input', this).get(index).checked = visibility;
              });
            }
            
            $.each(myself.dataTables, function () {
              this.fnSetColumnVis(col, visibility);
              options.fnDrawCallback(this.fnSettings());
            });
          }
          
          input = null;
        }).append($('<input>', {
          type: 'checkbox',
          checked: columns[col].bVisible,
          disabled: th.hasClass('no_hide')
        })).append(
          '<span>' + th.text() + '</span>'
        ).appendTo(toggleList);
        
        th = null; 
      });
      
      $('.col_toggle', table.parent()).append(toggle, toggleList);
      
      myself.dataTables = myself.dataTables || [];
      myself.dataTables.push(dataTable);
      
      table = null;
      dataTable = null;
    });
  }
});
