// $Revision$

Ensembl.Panel.Content = Ensembl.Panel.extend({
  init: function () {    
    this.base();
    this.ajaxLoad();
    
    this.hideHints();
    this.toggleTable();
    this.dataTable();
    this.toggleList();
    
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
        var popup = el.children('.glossary_popup');
        
        var position = el.position();
        position.top  -= popup.height() - (0.25 * el.height());
        position.left += 0.75 * el.width();
        
        popup.show().css(position);
        popup = null;
        el = null;
      },
      mouseout: function () {
        $(this).children('.glossary_popup').hide();
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
      
      if (Ensembl.hideHints[this.id]) {
        div.hide();
      } else {
        $('<img src="/i/close.gif" alt="Hide hint panel" title="Hide hint panel" />').click(function () {
          var tmp = [];
          
          div.hide();
          
          Ensembl.hideHints[div.attr('id')] = 1;
          
          for (var i in Ensembl.hideHints) {
            tmp.push(i);
          }
          
          Ensembl.cookie.set('ENSEMBL_HINTS', tmp.join(':'));
        }).prependTo(this.firstChild);
      }
    });
  },
  
  toggleTable: function () {    
    var table = $('.toggle_table', this.el);
    
    if (!table.length) {
      return;
    }
    
    var button = $('.toggle_button', this.el);
    var id     = table.attr('id');
    
    if (Ensembl.cookie.get('ENSEMBL_' + id) == 'close') {
      table.hide();
      button.html('Show ' + id);
    } else {
      table.show();
    }
    
    button.click(function () {
      table.toggle().parent('.dataTables_wrapper').toggle();
      
      if (table.is(':visible')) {
        Ensembl.cookie.set('ENSEMBL_' + id, 'open');
        this.innerHTML = 'Hide ' + id;
      } else {
        Ensembl.cookie.set('ENSEMBL_' + id, 'close');
        this.innerHTML = 'Show ' + id;
      }
    }).show();
    
    button = null;
  },
  
  dataTable: function () {
    $('table.data_table', this.el).each(function () {
      var table  = $(this);
      var length = $('tbody tr', this).length;
      var width  = table.width();
      var noSort = table.hasClass('no_sort');
      var config = table.siblings('form.data_table_config');
      var menu   = '';
      var sDom;
      
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
        sDom = '<"dataTables_top"lf<"invisible">>t<"dataTables_bottom"i<"col_toggle">p<"invisible">>';
        
        $.each([ 10, 25, 50, 100 ], function () {
          if (this < length) {
            menu += '<option value="' + this + '">' + this + '</option>';
          }
        });
        
        menu += '<option value="-1">All</option>';
      } else {
        sDom = '<"dataTables_top"f<"invisible">>t<"dataTables_bottom"<"col_toggle"><"invisible">>'
      }
      
      var options = {
        aoColumns: cols,
        aaSorting: [],
        sDom: 't',
        asStripClasses: [ 'bg1', 'bg2' ],
        oLanguage: {
          sLengthMenu: 'Show <select>' + menu + '</select> entries'
        },
        fnInitComplete: function (data) {
          $(data.nTable).width(width).parent().width(width);
          
          if (!$(data.nTable).is(':visible')) {
            $(data.nTable).parent().hide();
          }
        },
        bPaginate: false,
        bSort: false
      };
      
      $('input', config).each(function () {
        options[this.name] = eval(this.value);
      });
      
      table.dataTable(options);
      
      table = null;
    });
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
  }
});
