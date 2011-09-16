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
    
    if (this.el.hasClass('ajax')) {
      $.extend(fnEls.ajaxLoad, this.el);
    }
    
    $.extend(this.elLk, fnEls);
    
    for (var fn in fnEls) {
      if (fnEls[fn].length) {
        this[fn]();
      }
    }
    
    Ensembl.EventManager.register('updatePanel', this, this.getContent);
    
    if (this.el.parent('.initial_panel')[0] === Ensembl.initialPanels.get(-1)) {
      Ensembl.EventManager.register('hashChange', this, this.hashChange);
    }
    
    Ensembl.EventManager.trigger('validateForms', this.el);
    Ensembl.EventManager.trigger('relocateTools', $('.other_tool', this.el));
    
    // Links in a popup (help) window should make a new window in the main browser
    if (window.name.match(/^popup_/)) {
      $('a:not(.cp-internal, .popup)', this.el).bind('click', function () {
        window.open(this.href, window.name.replace(/^popup_/, '') + '_1');
        return false;
      });
    }
    
    $('a.toggle[rel], .ajax_add', this.el).bind('click', function (e) {
      if ($(this).hasClass('ajax_add')) {
        var url = $('input.url', this).val();
        
        if (url) {
          if (panel.elLk[this.rel]) {
            panel.toggleContent(this.rel);
            window.location.hash = panel.elLk[this.rel][0].id;
          } else {
            $(this).toggleClass('open closed');
            panel.elLk[this.rel] = panel.addContent(url, this.rel);
          }
        }
      } else {
        panel.toggleContent(this.rel);
      }
      
      return false;
    }).filter('.closed').each(function () {
      if (Ensembl.hash.indexOf(';' + this.rel + ';') !== -1 || Ensembl.hash.indexOf('?' + this.rel + ';') !== -1) {
        $(this).trigger('click');
      }
    });
  },
  
  ajaxLoad: function () {
    var panel = this;
    
    $('.navbar', this.el).width(Ensembl.width);
    
    this.elLk.ajaxLoad.each(function () {
      var el   = $(this);
      var urls = $('input.ajax_load', this).map(function () { return this.value; }).toArray();
      var content, caption, component, referer, url, params, i, j;
      
      if (!urls.length) {
        return;
      }
      
      if (urls[0].substr(0, 1) !== '/') {
        caption = urls.shift();
        content = $('<div class="content"></div>');
        
        el.append('<h4>' + caption + '</h4>').append(content);
      } else {
        content = el;
      }
      
      for (i = 0; i < urls.length; i++) {
        component = urls[i];
        
        if (component.substr(0, 1) === '/') {
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
          } else {
            component += '?';
          }
          
          panel.getContent(component, content, { updateURL: component + ';update_panel=1' });
        }
      }
      
      el = content = null;
    });
  },
  
  getContent: function (url, el, params, newContent) {
    var node;
    
    params = params || this.params;
    url    = url    || Ensembl.replaceTimestamp(params.updateURL);
    el     = el     || this.el.empty();
    
    switch (el[0].nodeName) {
      case 'DL': node = 'dt'; break;
      case 'UL': 
      case 'OL': node = 'li'; break;
      default  : node = 'p';  break;
    }
    
    el.append('<' + node + ' class="spinner">Loading component</' + node + '>');
    
    Ensembl.EventManager.trigger('hideZMenu', this.id); // Hide ZMenus based on this panel
    
    if (newContent) {
      window.location.hash = el[0].id; // Jump to the newly added div
    }
    
    this.xhr = $.ajax({
      url: url,
      dataType: 'html',
      context: this,
      success: function (html) {
        if (html) {
          Ensembl.EventManager.trigger('addPanel', undefined, $((html.match(/<input[^<]*class=".*?panel_type.*?".*?>/) || [])[0]).val() || 'Content', html, el, params);
          Ensembl.EventManager.trigger('ajaxLoaded');
          
          if (newContent) {
            // Jump to the newly added content. Set the hash to a dummy value first so the browser is forced to jump again
            window.location.hash = '_';
            window.location.hash = el[0].id;
          }
        } else {
          el.html('');
        }
      },
      error: function (e) {
        if (e.status !== 0) { // e.status === 0 when navigating to a new page while request is still loading
          el.html('<p class="ajax_error">Sorry, the page request "' + url + '" failed to load.</p>');
        }
      },
      complete: function () {
        el = null;
        this.xhr = false;
      }
    });
  },
  
  addContent: function (url, rel) {
    var newContent = $('<div class="js_panel">').appendTo(this.el);
    var i          = 1;
    
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
  
  toggleContent: function (rel) {
    if (this.id === rel) {
      $('.toggleable', this.el).toggle();
    } else {
      if (!this.elLk[rel]) {
        this.elLk[rel] = $('.' + rel, this.el);
      }
      
      $('.toggleable', this.elLk[rel]).toggle();
    }
    
    Ensembl.EventManager.trigger('toggleContent', rel);
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
        
        Ensembl.hideHints[div[0].id] = 1;
        
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
    this.elLk.toggleList.bind('click', function () {
      $(this).toggleClass('open').siblings('ul.shut').toggle();
      return false;
    });
  },
  
  glossary: function () {
    this.elLk.glossary.bind({
      mouseover: function () {
        var el         = $(this);
        var popup      = el.children('.floating_popup');
        var position   = el.position();
        position.top  -= popup.height() - (0.25 * el.height());
        position.left += 0.75 * el.width();
        
        popup.show().css(position);
        
        popup = el = null;
      },
      mouseout: function () {
        $(this).children('.floating_popup').hide();
      }
    });
  },
  
  dataTable: function () {
    $.extend(this, Ensembl.DataTable);
    this.dataTableInit();
  }
});
