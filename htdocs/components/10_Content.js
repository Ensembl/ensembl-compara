// $Revision$

Ensembl.Panel.Content = Ensembl.Panel.extend({
  init: function () {
    var panel = this;
    
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
    
    if ($(this.el).hasClass('ajax')) {
      $.extend(fnEls.ajaxLoad, $(this.el));
    }
    
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
    
    Ensembl.EventManager.register('updatePanel',  this, this.getContent);
    Ensembl.EventManager.register('ajaxComplete', this, this.getSequenceKey);
    Ensembl.EventManager.register('ajaxLoaded',   this, function (id) {
      if (id) {
        // Jump to the newly added content
        window.location.hash = id;
      }
    });
    
    if ($(this.el).parent('.initial_panel')[0] == Ensembl.initialPanels.get(-1)) {
      Ensembl.EventManager.register('hashChange', this, this.hashChange);
    }
    
    Ensembl.EventManager.trigger('validateForms', this.el);
    Ensembl.EventManager.trigger('relocateTools', $('.other-tool', this.el));
    
    // Links in a popup (help) window should make a new window in the main browser
    if (window.name.match(/^popup_/)) {
      $('a', this.el).bind('click', function () {
        window.open(this.href, window.name.replace(/^popup_/, '') + '_1');
        return false;
      });
    }
    
    $('a.ajax_add', this.el).bind('click', function () {
      var url = $('input.url', this).val();
      
      if (url) {
        if (panel.elLk[url]) {
          panel.elLk[url].show().children().show();
          window.location.hash = panel.elLk[url][0].id;
        } else {
          panel.elLk[url] = panel.addContent(url, this.rel);
        }
      }
      
      return false;
    });
    
    $('a.toggle[rel]', this.el).bind('click', function () {
      if (panel.id == this.rel) {
        $(panel.el).children().not($(this).parentsUntil(panel.id)).toggle();
      } else {
        $('.' + this.rel, panel.el).toggle();
      }
      
      $(this).toggleClass('open closed');
      
      return false;
    });
  },
  
  ajaxLoad: function () {
    var panel = this;
    
    $('.navbar', this.el).width(Ensembl.width);
    
    this.elLk.ajaxLoad.each(function () {
      var el   = $(this);
      var urls = $('input.ajax_load', this).map(function () { return this.value; });
      var content, caption, component, referer, url, params, i, j;
      
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
      
      for (i = 0; i < urls.length; i++) {
        component = urls[i];
        
        if (component.substr(0, 1) == '/') {
          if (component.match(/\?/)) {
            referer = '';
            url     = [];
            params  = component.split(/;/);
            j       = params.length;
            
            while (j--) {
              if (params[j].match(/^_referer=/)) {
                referer = params[j];
              } else {
                url.unshift(params[j]);
              }
            }
            
            component = Ensembl.replaceTimestamp(url.join(';')) + referer;
          }
          
          panel.getContent(component, content, { updateURL: component + ';update_panel=1' });
        }
      }
      
      el      = null;
      content = null;
    });
  },
  
  getContent: function (url, el, params, newContent) {
    var node;
    
    params = params || this.params;
    url    = url    || Ensembl.replaceTimestamp(params.updateURL);
    el     = el     || $(this.el).empty();
    
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
      context: this,
      success: function (html) {
        if (html) {
          Ensembl.EventManager.trigger('addPanel', undefined, $((html.match(/<input[^<]*class=".*?panel_type.*?".*?>/)||[])[0]).val() || 'Content', html, el, params);
          Ensembl.EventManager.trigger('ajaxLoaded', newContent === true ? '#' + el[0].id : '');
        } else {
          el.html('');
        }
      },
      error: function (e) {
        el.html('<p class="ajax_error">Sorry, the page request "' + url + '" timed out. Please try selecting less data.</p>');
      },
      complete: function () {
        el = null;
        this.xhr = false;
      }
    });
  },
  
  addContent: function (url, rel) {
    var newContent = $('<div class="js_panel">').appendTo(this.el);
    var i = 1;
    
    if (rel) {
      newContent.addClass(rel);
    } else {
      rel = 'anchor';
    }
    
    // Ensure unique id
    while (document.getElementById(rel)) {
      rel += i++;
    }
    
    newContent.attr('id', rel);
    
    this.getContent(url, newContent, this.params, true);
    
    return newContent;
  },
  
  hashChange: function () {
    this.params.updateURL = Ensembl.urlFromHash(this.params.updateURL);
    
    if (this.xhr) {
      this.xhr.abort();
      this.xhr = false;
    }
    
    this.getContent(Ensembl.replaceTimestamp(this.params.updateURL + ';hash_change=' + Ensembl.lastR));
  },
  
  hideHints: function () {
    this.elLk.hideHints.each(function () {
      var div = $(this);
      
      $('<img src="/i/close.gif" alt="Hide hint panel" title="Hide hint panel" />').bind('click', function () {
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
    var panel = this;
    
    $('.toggle_button', this.el).bind('click', function () {
      var visible = panel.elLk.toggleTable.filter('#' + this.id + '_table').toggle().parent('.toggleTable_wrapper').toggle().end().is(':visible');
      $(this).siblings('.toggle_info').toggle().end().children('em').toggleClass('open closed');
      Ensembl.cookie.set('ENSEMBL_' + this.id, visible ? 'open' : 'close');
    }).children('em').show();
  },
  
  toggleList: function () {
    var attrs = {
      open: { src: '/i/list_open.gif', alt: 'V' },
      shut: { src: '/i/list_shut.gif', alt: '>' }
    };
    
    this.elLk.toggleList.bind('click', function () {
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
    var panel = this;
    
    this.elLk.dataTable.each(function (i) {
      var table    = $(this);
      var length   = $('tbody tr', this).length;
      var width    = table.hasClass('fixed_width') ? table.outerWidth() : '100%';
      var noSort   = table.hasClass('no_sort');
      var noToggle = table.hasClass('no_col_toggle');
      var menu     = [[],[]];
      var sDom;
      
      var cookieId      = this.id || 'data_table' + panel.panelNumber;
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
        sDom = '<"dataTables_top"l' + (noToggle ? '' : '<"col_toggle">') + 'f<"invisible">>t<"dataTables_bottom"ip<"invisible">>';
        
        $.each([ 10, 25, 50, 100 ], function () {
          if (this < length) {
            menu[0].push(this);
            menu[1].push(this);
          }
        });
        
        menu[0].push(-1);
        menu[1].push('All');
      } else {
        sDom = '<"dataTables_top"' + (noToggle ? '' : '<"col_toggle left">') + 'f<"invisible">>t';
      }
      
      var options = {
        sPaginationType: 'full_numbers',
        aoColumns: cols,
        aaSorting: [],
        aoColumnDefs: [],
        sDom: sDom,
        asStripClasses: [ 'bg1', 'bg2' ],
        iDisplayLength: -1,
        bAutoWidth: false,
        aLengthMenu: menu,
        oLanguage: {
          sSearch: 'Filter: ',
          oPaginate: {
            sFirst:    '&lt;&lt;',
            sPrevious: '&lt;',
            sNext:     '&gt;',
            sLast:     '&gt;&gt;'
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
        var val = JSON.parse(this.value.replace(/'/g, '"'));
        
        if (typeof options[this.name] == 'object') {
          $.extend(true, options[this.name], val);
        } else {
          options[this.name] = val;
        }
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
      
      if (!noToggle) {
        panel.elLk.colToggle = $('.col_toggle', panel.el);
        
        var columns    = dataTable.fnSettings().aoColumns;
        var toggleList = $('<ul class="floating_popup"></ul>');
        var toggle     = $('<div class="toggle">Show/hide columns</div>').append(toggleList).bind('click', function (e) {
          if (e.target == this) {
            toggleList.toggle();
          }
        });
        
        $.each(columns, function (col) {
          var th = $(this.nTh);
          
          $('<li>', {
            html: '<input type="checkbox"' + (th.hasClass('no_hide') ? ' disabled' : '') + (columns[col].bVisible ? ' checked' : '') + ' /><span>' + th.text() + '</span>',
            click: function () {
              var input = $('input', this);
              
              if (!input.attr('disabled')) {
                var visibility = !columns[col].bVisible;
                
                if (panel.elLk.colToggle.length == 1) {
                  input.attr('checked', visibility);
                } else {
                  var index = $(this).index();
                  
                  panel.elLk.colToggle.each(function () {
                    $('input', this).get(index).checked = visibility;
                  });
                }
                
                $.each(panel.dataTables, function () {
                  this.fnSetColumnVis(col, visibility);
                });
              }
            
              input = null;
            }
          }).appendTo(toggleList);
          
          th = null; 
        });
        
        $('.col_toggle', table.parent()).append(toggle);
      }
      
      panel.dataTables = panel.dataTables || [];
      panel.dataTables.push(dataTable);
      
      table     = null;
      dataTable = null;
    });
  },
  
  getSequenceKey: function () {
    var panel  = this;
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
      
      panel.getContent(panel.params.updateURL.replace(/\?/, '/key?') + ';' + $.param(urlParams, true), $('.sequence_key', panel.el));
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
