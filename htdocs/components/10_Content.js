// $Revision$

Ensembl.Panel.Content = Ensembl.Panel.extend({
  init: function () {
    this.base();
    
    this.xhr = false;
    
    var fnEls = {
      ajaxLoad:    $('.ajax', this.el),
      hideHints:   $('.hint', this.el),
      toggleTable: $('.toggle_table', this.el),
      toggleList:  $('a.collapsible', this.el),
      glossary:    $('.glossary_mouseover', this.el),
      dataTable:   $('table.data_table', this.el)
    };
    
    $.extend(this.elLk, fnEls);
    
    for (var fn in fnEls) {
      if (fnEls[fn].length) {
        if (fn == 'dataTable' && !window.JSON) {
          Ensembl.loadScript('/components/json2.js', fn, this);
        } else {
          this[fn]();
        }
      }
    }
    
    Ensembl.EventManager.register('updatePanel', this, this.getContent);
    Ensembl.EventManager.register('ajaxComplete', this, this.getSequenceKey);
    Ensembl.EventManager.register('cancelLocationChange', this, function () {if (this.xhr) { this.xhr.abort(); this.xhr = false; } });
    
    // This event registration must be in the init, because it can overwrite the one in Ensembl.Panel.ImageMap's constructor
    if ($(this.el).parent('.initial_panel')[0] == Ensembl.initialPanels.get(-1)) {
      Ensembl.EventManager.register('hashChange', this, function () {
        this.params.updateURL = Ensembl.urlFromHash(this.params.updateURL);
        this.getContent();
      });
    }
    
    Ensembl.EventManager.trigger('validateForms', this.el);
    Ensembl.EventManager.trigger('relocateTools', $('.other-tool', this.el));
    
    // Links in a popup (help) window should make a new window in the main browser
    if (window.name.match(/^popup_/)) {
      $('a', this.el).click(function () {
        window.open(this.href, window.name.replace(/^popup_/, '') + '_1');
        return false;
      });
    }
  },
  
  ajaxLoad: function () {
    var myself = this;
    
    if ($(this.el).hasClass('ajax')) {
      $.extend(this.elLk.ajaxLoad, $(this.el));
    }    
    
    $('.navbar', this.el).width(Ensembl.width);
    
    this.elLk.ajaxLoad.each(function () {
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
              if (params[j].match(/^_referer=/)) {
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
  },
  
  getContent: function () {
    var args = [].slice.call(arguments);
    var node;
    
    if (args[0] == 'hashChange') {
      args.shift();
    }
    
    var params = args[2] || this.params;
    var url    = args[0] || params.updateURL;
    var el     = args[1] || $(this.el).empty();
    
    switch (el.attr('nodeName')) {
      case 'DL': node = 'dt'; break;
      case 'UL': 
      case 'OL': node = 'li'; break;
      default  : node = 'p';  break;
    }
    
    el.append('<' + node + ' class="spinner">Loading component</' + node + '>');
    
    Ensembl.EventManager.trigger('hideZMenu', this.id); // Hide ZMenus based on this panel
    
    this.xhr = $.ajax({
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
        this.xhr = false;
      }
    });
  },
  
  hideHints: function () {
    this.elLk.hideHints.each(function () {
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
    var myself = this;
    var id     = this.elLk.toggleTable[0].id;
    var button = $('.toggle_button', this.el);
    var icon   = button.children('em').show();
    var info   = button.siblings('.toggle_info');
  
    button.click(function () {
      myself.elLk.toggleTable.toggle().parent('.toggleTable_wrapper').toggle();
      info.toggle();
      icon.toggleClass('open closed');
      Ensembl.cookie.set('ENSEMBL_' + id, myself.elLk.toggleTable.is(':visible') ? 'open' : 'close');
    });
    
    button = null;
  },
  
  toggleList: function () {
    var attrs = {
      open: { src: '/i/list_open.gif', alt: 'V' },
      shut: { src: '/i/list_shut.gif', alt: '>' }
    };
    
    this.elLk.toggleList.click(function () {
      var img = $('img', this);
      
      img.attr(attrs[img.hasClass('open') ? 'shut' : 'open']).toggleClass('open');
      img = null;
      
      $(this).siblings('ul.shut').toggle();
      
      return false;
    });
  },
  
  glossary: function () {
    this.elLk.glossary.bind({
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
  
  dataTable: function () {
    var myself = this;
    
    this.elLk.dataTable.each(function (i) {
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
        sDom = '<"dataTables_top"<"col_toggle">f<"invisible">>t';
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
          $('.dataTables_info, .dataTables_paginate, .dataTables_bottom', $(data.nTable).parent())[data._iDisplayLength == -1 ? 'hide' : 'show']();
          
          var sort   = $.map(data.aaSorting, function (s) { return '[' + s.toString().replace(/([a-z]+)/g, '"$1"') + ']'; });
          var hidden = $.map(data.aoColumns, function (c, j) { return c.bVisible ? null : j; });
          
          Ensembl.cookie.set(cookieName, '[' + sort.join(',') + ']' + (hidden.length ? '#' + hidden.join(',') : ''), 1, true);
          
          Ensembl.EventManager.trigger('dataTableRedraw');
        }
      };
      
      // Extend options from config defined in the html
      $('input', table.siblings('form.data_table_config')).each(function () {
        options[this.name] = JSON.parse(this.value.replace(/'/g, '"'));
      });
      
      // Extend options from the cookie
      if (cookieOptions) {
        cookieOptions = cookieOptions.replace(/#$/, '').split('#');
        
        var sorting = JSON.parse(cookieOptions[0]);
        
        if (sorting.length) {
          options.aaSorting = $.grep(sorting, function (s) { return s[0] < cols.length; });
        }
        
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
        }).append(
          '<input type="checkbox"' + (th.hasClass('no_hide') ? ' disabled' : '') + (columns[col].bVisible ? ' checked' : '') + ' /><span>' + th.text() + '</span>'
        ).appendTo(toggleList);
        
        th = null; 
      });
      
      $('.col_toggle', table.parent()).append(toggle, toggleList);
      
      myself.dataTables = myself.dataTables || [];
      myself.dataTables.push(dataTable);
      
      table = null;
      dataTable = null;
    });
  },
  
  getSequenceKey: function () {
    var params = {};
    var urlParams;
    
    function getKey() {
      $('.sequence_key_json', this.el).each(function () {
        $.extend(true, params, JSON.parse(this.innerHTML));
      });
      
      urlParams = $.extend({}, params, { variations: [], exons: [] });
      
      $.each([ 'variations', 'exons' ], function () {
        for (var p in params[this]) {
          urlParams[this].push(p);
        }
      });
      
      this.getContent(this.params.updateURL.replace(/\?/, '/key?') + ';' + $.param(urlParams, true), $('.sequence_key', this.el));
    }
    
    if ($('> .ajax > .js_panel > input.panel_type[value=TextSequence]', this.el).length) {
      if (!window.JSON) {
        Ensembl.loadScript('/components/json2.js', getKey);
      } else {
        getKey();
      }
    }
  }
});
