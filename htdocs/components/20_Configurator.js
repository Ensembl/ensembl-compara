// $Revision$

Ensembl.Panel.Configurator = Ensembl.Panel.ModalContent.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    Ensembl.EventManager.register('updateConfiguration', this, this.updateConfiguration);
    Ensembl.EventManager.register('showConfiguration', this, this.show);
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    this.elLk.form          = $('form.configuration', this.el);
    this.elLk.search        = $('.configuration_search_text', this.el);
    this.elLk.help          = $('.menu_help', this.elLk.form);
    this.elLk.menus         = $('.popup_menu', this.elLk.form);
    this.elLk.searchResults = $('a.search_results', this.elLk.links);
    
    this.initialConfig = {};
    this.lastQuery     = false;
    
    $.each(this.elLk.form.serializeArray(), function () {
      panel.initialConfig[this.name] = this.value;
    });
    
    if (this.params.hash) {
      this.elLk.links.removeClass('active').has('.' + this.params.hash).addClass('active');
      delete this.params.hash;
    }
    
    this.getContent();
    
    $('input.submit', this.elLk.form).hide();
    
    this.elLk.help.bind('click', function () { panel.toggleDescription(this); });
    
    // Popup menus - displaying
    $('.menu_option', this.elLk.form).bind('click', function () {
      var menu = $(this).siblings('.popup_menu');
      
      if (menu.children().length == 2 && !$(this).parent().hasClass('select_all')) {
        menu.children(':not(.' + $(this).siblings('input').val() + ')').trigger('click');
      } else {
        panel.elLk.menus.filter(':visible').not(menu).hide();
        menu.toggle();
      }
      
      menu = null;
    });
    
    // Popup menus - setting values
    $('li', this.elLk.menus).bind('click', function () {
      var li    = $(this);
      var img   = li.children('img');
      var menu  = li.parents('.popup_menu');
      var dt    = menu.parent();
      var val   = li.attr('className');
      var link  = panel.elLk.links.children('a.' + img.attr('className'));
      var label = link.html().split(/\b/);
      
      if (dt.hasClass('select_all')) {
        dt = dt.siblings('dt.internal');
        
        if (val == 'all_on') {
          // First li is off, so use the second (index 1) as default on setting.
          dt.find('li:eq(1)').each(function () {
            var text = $(this).text();
            
            $(this).parent().siblings('img.menu_option').attr({ 
              src:   '/i/render/' + this.className + '.gif', 
              alt:   text,
              title: text
            }).siblings('input').attr('newVal', this.className);
          });
        }
      }
      
      dt.children('input').each(function () {
        var input = $(this);
        
        if (input.val() == 'off' ^ val == 'off') {
          label[1] = parseInt(label[1], 10) + (val == 'off' ? -1 : 1);
        }
        
        input.val(input.attr('newVal') || val).removeAttr('newVal');
        input = null;
      });
      
      if (val != 'all_on') {
        dt.children('img.menu_option').attr({ 
          src:   '/i/render/' + val + '.gif', 
          alt:   li.text(),
          title: li.text()
        });
      }
      
      label = label.join('');
      link.attr('title', label).html(label);
      menu.hide();
      
      menu = null;
      dt   = null;
      link = null;
      img  = null;
      li   = null;
    });
    
    this.elLk.search.bind({
      keyup: function () {
        if (this.value.length < 3) {
          panel.lastQuery = this.value;
        }
        
        if (this.value != panel.lastQuery) {
          if (panel.searchTimer) {
            clearTimeout(panel.searchTimer);
          }
          
          panel.query = this.value;
          panel.regex = new RegExp(this.value, 'i');
          
          panel.searchTimer = setTimeout(function () {
            panel.elLk.links.removeClass('active');
            panel.elLk.searchResults.removeClass('disabled').parent().addClass('active');
            panel.search(); 
          }, 250);
        }
      },
      focus: function () {
        this.value = '';
      }
    });
    
    // Header on search results and active tracks sections will act like the links on the left
    $('div.config > h2', this.elLk.form).css('cursor', 'pointer').bind('click', function () {
      var link = $(this).parent().attr('className').replace(/\s*config\s*/, '');
      $('a.' + link, panel.elLk.links).trigger('click');
    });
  },
  
  show: function (active) {
    this.elLk.menus.hide();
    
    if (active) {
      this.elLk.links.removeClass('active').has('.' + active).addClass('active');
    }
    
    this.base();
    this.getContent();
  },
  
  updateConfiguration: function (delayReload) {
    if ($('input.invalid', this.elLk.form).length) {
      return;
    }
    
    var panel   = this;
    var d       = false;
    var diff    = { config: this.initialConfig.config };
    var checked = $.extend({}, this.initialConfig);
    
    $.each(this.elLk.form.serializeArray(), function () {
      if (this.value != panel.initialConfig[this.name]) {
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
    $.ajax({
      url:  this.elLk.form.attr('action'),
      type: this.elLk.form.attr('method'),
      data: diff,
      dataType: 'json',
      success: function (json) {
        if (json.updated) {
          Ensembl.EventManager.trigger('queuePageReload', diff.config, !delayReload);
        } else if (json.redirect) {
          Ensembl.redirect(json.redirect);
        }
      }
    });
  },
   
  getContent: function () {
    var active = this.elLk.links.filter('.active').children('a').attr('className');
    
    if (typeof active == 'undefined') {
      active = this.elLk.links.first().addClass('active').children('a').attr('className');
    }
    
    if (active == 'search_results') {
      this.elLk.search.val(this.query);
      this.search();
    } else if (typeof active != 'undefined') {
      $('div:not(.' + active + '), dd', this.elLk.form).hide();
      this.elLk.help.html('Show info');
      
      if (active == 'active_tracks') {
        $('dl.config_menu input', this.elLk.form).each(function () {
          if (this.value == 'off') {
            $(this).parent().hide().next('dd').hide(); // Hide the dt and the dd corresponding to it
          } else {
            $(this).parents('dt, div.config').show();
          }
        });
      } else {
        $('div.' + active, this.elLk.form).show().find('dl.config_menu dt').show();
      }
      
      this.lastQuery = false;
      this.styleTracks(active == 'active_tracks');
    }
  },
  
  styleTracks: function (special) {
    var col    = { 1: 'col1', '-1': 'col2', f: 1 };
    var margin = 0;
    
    if (special === true) {
      $('.select_all, .external', this.elLk.form).hide();
      $('.submenu', this.elLk.form).css('marginTop', 0);
    } else {
      margin = 10;
      $('.submenu', this.elLk.form).removeAttr('style');
    }
    
    $('dl.config_menu:visible', this.elLk.form).each(function () {
      var internal = $('dt:visible', this).each(function () {
        if ($(this).hasClass('external')) {
          col.f = 1; // Force colour reset for the start of the external section
        } else {
          $(this).removeClass('col1 col2').addClass(col[col.f*=-1])
            .next('dd').removeClass('col1 col2').addClass(col[col.f]);
        }
      }).filter('.internal');
      
      if (internal.siblings('.select_all').length) {
        internal.each(function () {
          var level = this.className.match(/level(\d+)/);
          $(this).css('marginLeft', margin * (level ? parseInt(level[1], 10) : 1));
        });
      }
      
      col.f    = 1;
      internal = null;
    });
  },
  
  // Filtering from the search box
  search: function () {
    var panel = this;
    var dts    = [];
    
    $('dl.config_menu', this.elLk.form).each(function () {
      var menu = $(this);
      var div  = menu.parent();
      
      if (!div[0].show) {
        div[0].show = false;
      }
      
      menu.children('dt:not(.select_all, .external)').each(function () {
        var dt    = $(this);
        var match = dt.children('span:not(.menu_help)').html().match(panel.regex);
        
        if (match || dt.next('dd').text().match(panel.regex)) {
          dt.show();
          div[0].show = true;
          
          if (!match) {
            dts.push(dt[0]);
          }
        } else {
          dt.hide().next('dd').hide();
        }
        
        dt = null;
      });
      
      if (div[0].show === true) {
        div.show();
      } else {
        div.hide();
      }
      
      menu = null;
      div  = null;
    });
    
    this.lastQuery = this.query;
    this.styleTracks(true);
    this.toggleDescription(dts, 'show');
    
    dts = null;
  },
  
  toggleDescription: function (els, action) {
    var dd, span, i;
    
    if (typeof els.length == 'undefined') {
      els = [ els ];
    }
    
    i = els.length;
    
    while (i--) {
      switch (els[i].nodeName) {
        case 'DT'  : dd = $(els[i]).next('dd'); span = $('.menu_help', els[i]); break;
        case 'SPAN': dd = $(els[i]).parent().next('dd'); span = $(els[i]); break;
        default    : return;
      }
      
      switch (action) {
        case 'hide': dd.hide(); break;
        case 'show': dd.show(); break;
        default    : dd.toggle();
      }
      
      span.html(dd.is(':visible') ? 'Hide info': 'Show info');
      
      dd   = null;
      span = null;
    }
  }
});
