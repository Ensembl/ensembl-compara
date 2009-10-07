// $Revision$

Ensembl.Panel.Configurator = Ensembl.Panel.ModalContent.extend({
  constructor: function (id) {
    this.base(id);
    
    Ensembl.EventManager.register('updateConfiguration', this, this.updateConfiguration);
    Ensembl.EventManager.register('showConfiguration', this, this.show);
  },
  
  init: function () {
    var myself = this;
    
    this.base();
    
    this.elLk.form = $('form.configuration', this.el);
    this.elLk.search = $('.configuration_search_text', this.el);
    this.elLk.help = $('.menu_help', this.el);
    this.elLk.menus = $('.popup_menu', this.el);
    this.elLk.searchResults = $('a.search_results', this.elLk.links);
    
    this.initialConfig = {};
    this.lastQuery = false;
    
    $.each(this.elLk.form.serializeArray(), function () {
      myself.initialConfig[this.name] = this.value;
    });
    
    this.getContent();
    
    $('input.submit', this.el).hide();
    
    this.elLk.help.click(function () { myself.toggleDescription(this); });
    
    $('img.selected', this.elLk.form).click(function () {
      var menu = $(this).siblings('.popup_menu');
      
      myself.elLk.menus.filter(':visible').not(menu).hide();
      menu.toggle();
      
      menu = null;
    });
    
    $('img', this.elLk.menus).click(function () {
      var menu = $(this).parents('.popup_menu');
      var dt = menu.parent();
      var li = $(this).parent();
      var input = $('input', dt);
      var val = li.attr('className');
      var link = myself.elLk.links.children('a.' + this.className);
      var label = link.html().split(/\b/);
      
      $('img.selected', dt).attr({ 
        src: '/i/render/' + val + '.gif', 
        title: li.text()
      });
      
      if (input.val() == 'off' ^ val == 'off') {
        label[1] = parseInt(label[1]) + (val == 'off' ? -1 : 1);
        label = label.join('');
        link.attr('title', label).html(label);
      }
      
      input.val(val);
      menu.hide();
      
      menu = null;
      dt = null;
      li = null;
      input = null;
      link = null;
    });
    
    this.elLk.search.keyup(function () {
      if (this.value.length < 3) {
        myself.lastQuery = this.value;
      }
      
      if (this.value != myself.lastQuery) {
        if (myself.searchTimer) {
          clearTimeout(myself.searchTimer);
        }
        
        myself.query = this.value;
        
        myself.searchTimer = setTimeout(function () {
          myself.elLk.links.removeClass('active');
          myself.elLk.searchResults.removeClass('disabled').parent().addClass('active');
          myself.search(); 
        }, 250);
      }
    }).focus(function () {
      this.value = '';
    });
    
    if (Ensembl.ajax != 'enabled') {
      $('a', this.elLk.links).click(function () {
        var link = $(this).parent();
        
        if (!link.hasClass('active')) {
          myself.elLk.links.removeClass('active');
          link.addClass('active');
          myself.getContent();
        }
        
        link = null;
        
        return false;
      });
    }
  },
  
  show: function () {
    this.elLk.menus.hide();
    this.getContent();
    this.base();
  },
  
  updateConfiguration: function (delayReload) {
    var myself = this;
    
    var d = false;
    var diff = { config: this.initialConfig.config };
    var checked = $.extend({}, this.initialConfig);
    
    $.each(this.elLk.form.serializeArray(), function () {
      if (this.value != myself.initialConfig[this.name]) {
        diff[this.name] = this.value;
        d = true;
      }
      
      delete checked[this.name];
    });
    
    // Add unchecked checkboxes to the diff
    for (var i in checked) {
      diff[i] = 'off';
      d = true;
    }
    
    if (d === true) {
      $.extend(this.initialConfig, diff);
      diff.submit = 1;
      
      this.updatePage(diff, delayReload);
      
      return true;
    }
  },
  
  updatePage: function (diff, delayReload) {
    var myself = this;
    
    if (Ensembl.ajax == 'enabled') {
      $.ajax({
        url: myself.elLk.form.attr('action'),
        type: myself.elLk.form.attr('method'),
        data: diff,
        dataType: 'html',
        success: function (html) {
          if (html == 'SUCCESS') {
            Ensembl.EventManager.trigger('queuePageReload', diff.config, !delayReload);
          } else {
            // TODO: show message on main page
          }
        },
        error: function (e) {
         // TODO: show message on main page
        }
      });
    } else {
      var queryString = [];
      var url = this.elLk.form.attr('action') + '?';
      
      for (var i in diff) {
        queryString.push(i + '=' + diff[i]);
      }
      
      window.open(url + queryString.join(';'), window.name.replace(/^cp_/, '')); // URL to update configuration
      window.close();
    }
  },
   
  getContent: function () {
    var active = this.elLk.links.filter('.active').children('a').attr('className');
    
    if (active == 'search_results') {
      this.elLk.search.val(this.query);
      this.search();
    } else {
      $('div:not(.' + active + ')', this.elLk.form).hide();
      $('dd', this.elLk.form).hide();
      this.elLk.help.html('Show info');
      
      if (active == 'active_tracks') {
        $('dl.config_menu input', this.elLk.form).each(function () {
          if (this.value == 'off') {
            $(this).parent().hide().next().hide(); // Hide the dt and the dd corresponding to it
          } else {
            $(this).parents('dt, div.config').show();
          }
        });
      } else {
        $('div.' + active, this.elLk.form).show().find('dl.config_menu dt').show();
      }
      
      this.lastQuery = false;
      this.styleTracks();
    }
  },
  
  styleTracks: function () {
    var col = { 1: 'col1', '-1': 'col2', f: 1 };
    
    $('dl.config_menu:visible', this.elLk.form).each(function () {
      $('dt:visible', this).each(function () {
        $(this).removeClass('col1 col2').addClass(col[col.f*=-1])
          .next('dd').removeClass('col1 col2').addClass(col[col.f]);
      });
      
      col.f = 1;
    });
  },
  
  // Filtering from the search box
  search: function () {
    var myself = this;
    var dts = [];
    
    $('dl.config_menu', this.elLk.form).each(function () {
      var menu = $(this);
      var div = menu.parent();
      var show = false;
      
      $('dt', menu).each(function () {
        var dt = $(this);
        
        if ($('span', dt).html().match(myself.query, 'i')) {
          dt.show();
          show = true;
        } else if (dt.next('dd').text().match(myself.query, 'i')) {
          dt.show();
          dts.push(dt[0]);
          show = true;
        } else {
          dt.hide().next('dd').hide();
        }
        
        dt = null;
      });
      
      if (show === true) {
        div.show();
      } else {
        div.hide();
      }
      
      menu = null;
      div = null;
    });
    
    this.lastQuery = this.query;
    this.styleTracks();
    this.toggleDescription(dts);
    
    dts = null;
  },
  
  toggleDescription: function (els) {
    var dd, span;
    
    if (typeof els.length == 'undefined') {
      els = [ els ];
    }
    
    for (var i in els) {
      switch (els[i].nodeName) {
        case 'DT'  : dd = $(els[i]).next(); span = $('.menu_help', els[i]); break;
        case 'SPAN': dd = $(els[i]).parent().next(); span = $(els[i]); break;
        default    : return;
      }
      
      dd.toggle();
      span.html(dd.is(':visible') ? 'Hide info': 'Show info');
      
      dd = null;
      span = null;
    }
  }
});
