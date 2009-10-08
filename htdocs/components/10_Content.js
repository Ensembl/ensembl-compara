// $Revision$

Ensembl.Panel.Content = Ensembl.Panel.extend({
  init: function () {
    var myself = this;
    
    this.base();
    this.ajaxLoad();
    
    this.hideHints();
    this.toggleTable();
    this.toggleList();
    
    Ensembl.EventManager.register('updatePanel', this, this.getContent);
    Ensembl.EventManager.trigger('validateForms', this.el);
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
      var content, caption, component, node;
      
      if (Ensembl.ajax != 'enabled') {
        el.append('<p class="ajax_error">AJAX is disabled in this browser</p>');
        return;
      }
      
      var title = eval(this.title); // TODO: use hidden inputs and .each instead of this and the for loop below. Don't eval.
      
      if (!title) {
        return;
      }
      
      var params = el.hasClass('image_panel') ? { highlight: (Ensembl.images.total == 1 || !(this == Ensembl.images.last)) } : {};
      
      el.removeAttr('title');
      
      if (title[0].substr(0, 1) != '/') {
        caption = title.shift();
        
        content = $('<div class="content"></div>');
        
        el.append('<h4>'+caption+'</h4>').append(content);
      } else {
        content = el;
      }
      
      for (var i = 0; i < title.length; i++) {
        component = title[i];
        
        if (component.substr(0, 1) == '/') {
          if (component.match(/\?/)) {
            component = Ensembl.replaceTimestamp(component);
          }
          
          params.updateURL = component + ';update=1';
          
          myself.getContent(component, content, params);
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
    el = el || $(this.el).empty();
    
    switch (el.attr('nodeName')) {
      case 'DL': node = 'dt'; break;
      case 'UL': 
      case 'OL': node = 'li'; break;
      default  : node = 'p';  break;
    }
    
    el.append('<'+node+' class="spinner">Loading component</'+node+'>');
    
    Ensembl.EventManager.trigger('hideZMenu', this.id); // Hide ZMenus based on this panel
    
    $.ajax({
      url: url,
      dataType: 'html',
      success: function (html) {
        if (html) {
          var type = html.match(/<map/) ? 'ImageMap' : 'Content';
          
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
    $('<div class="toggle_button">' + txt + id + '</div>').appendTo('.toggle_text', this.el).click(function () {
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
