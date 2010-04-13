// $Revision$

Ensembl.Panel.Content = Ensembl.Panel.extend({
  init: function () {    
    this.base();
    this.ajaxLoad();
    
    this.hideHints();
    this.toggleTable();
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
    
    var id = table.attr('id');
    var txt;
    
    if (Ensembl.cookie.get('ENSEMBL_' + id) == 'close') {
      table.hide();
      txt = 'show ';
    } else {
      table.show();
      txt = 'hide ';
    }
    
    // TODO: do this in perl, have it hidden. show in js.
    $('<div class="toggle_button">' + txt + id + '</div>').appendTo($('.toggle_text', this.el)).click(function () {
      table.toggle();
      
      if (table.is(':visible')) {
        Ensembl.cookie.set('ENSEMBL_' + id, 'open');
        this.innerHTML = 'hide ' + id;
      } else {
        Ensembl.cookie.set('ENSEMBL_' + id, 'close');
        this.innerHTML = 'show ' + id;
      }
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
