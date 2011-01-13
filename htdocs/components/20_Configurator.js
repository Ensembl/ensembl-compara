// $Revision$

Ensembl.Panel.Configurator = Ensembl.Panel.ModalContent.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    Ensembl.EventManager.register('updateConfiguration', this, this.updateConfiguration);
    Ensembl.EventManager.register('showConfiguration',   this, this.show);
    Ensembl.EventManager.register('changeConfiguration', this, this.externalChange);
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    this.elLk.form          = $('form.configuration', this.el);
    this.elLk.search        = $('.configuration_search_text', this.el);
    this.elLk.help          = $('.menu_help', this.elLk.form);
    this.elLk.favourite     = $('.favourite', this.elLk.form);
    this.elLk.menus         = $('.popup_menu', this.elLk.form);
    this.elLk.searchResults = $('a.search_results', this.elLk.links);
    
    this.imageConfig   = $('input[name=config]', this.elLk.form).val();
    this.initialConfig = {};
    this.lastQuery     = false;
    
    if (this.imageConfig) {
      $.each(this.elLk.form.serializeArray(), function () { panel.initialConfig[this.name] = { renderer: this.value }; });
    } else {
      $.each(this.elLk.form.serializeArray(), function () { panel.initialConfig[this.name] = this.value; });
    }
    
    if (this.params.hash) {
      this.elLk.links.removeClass('active').has('.' + this.params.hash).addClass('active');
      delete this.params.hash;
    }
    
    this.getContent();
    
    $('input.submit', this.elLk.form).hide();
    
    this.elLk.help.bind('click', function () { panel.toggleDescription(this); });
    
    this.elLk.favourite.bind('click', function () {
      var li = $(this).toggleClass('selected').parents('li:first').toggleClass('fav');
      
      if (panel.elLk.links.filter('.active').children('a').attr('className') == 'favourite_tracks') {
        li.hide(); // Always hide, since the only way a click can come here is from a selected track
        
        if (!li.siblings(':visible').length) {
          li.parents('div.config').hide();
        }
      }
      
      li = null;
    }).filter('.selected').each(function () {
      panel.initialConfig[$(this).parents('li:first').toggleClass('fav')[0].id].favourite = 1;
    });
    
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
      var track = menu.parent();
      var val   = li.attr('className');
      var link  = panel.elLk.links.children('a.' + img.attr('className'));
      var label = link.html().split(/\b/);
      
      if (track.hasClass('select_all')) {
        track = track.next().find('li');
        
        if (val == 'all_on') {
          // First li is off, so use the second (index 1) as default on setting.
          track.find('li:eq(1)').each(function () {
            var text = $(this).text();
            
            $(this).parent().siblings('img.menu_option:not(.select_all)').attr({ 
              src:   '/i/render/' + this.className + '.gif', 
              alt:   text,
              title: text
            }).siblings('input').attr('newVal', this.className);
          });
        }
      }
      
      track.children('input').each(function () {
        var input = $(this);
        
        if (input.val() == 'off' ^ val == 'off') {
          label[1] = parseInt(label[1], 10) + (val == 'off' ? -1 : 1);
        }
        
        input.val(input.attr('newVal') || val).removeAttr('newVal');
        input = null;
      });
      
      if (val != 'all_on') {
        track.children('img.menu_option').attr({ 
          src:   '/i/render/' + val + '.gif', 
          alt:   li.text(),
          title: li.text()
        });
      }
      
      label = label.join('');
      link.attr('title', label).html(label);
      menu.hide();
      
      menu  = null;
      track = null;
      link  = null;
      img   = null;
      li    = null;
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
    $('div.config .config_header', this.elLk.form).bind('click', function () {
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
    
    var panel = this;
    var d     = false;
    var f     = false;
    var diff  = {};
    var checked, favourites;
    
    if (this.imageConfig) {
      favourites = {};
      
      $('li.fav', this.elLk.form).each(function () { favourites[this.id] = 1; });
      
      $.each(this.elLk.form.serializeArray(), function () {
        var fav = !panel.initialConfig[this.name].favourite &&  favourites[this.name] ? 1 : // Making a track a favourite
                   panel.initialConfig[this.name].favourite && !favourites[this.name] ? 0 : // Making a track not a favourite
                   false;
        
        if (panel.initialConfig[this.name].renderer != this.value) {
          diff[this.name] = { renderer: this.value };
          d = true;
        }
        
        if (fav !== false) {
          diff[this.name] = diff[this.name] || {};
          diff[this.name].favourite = fav;
          
          f = true;
        }
      });
    } else {
      checked = $.extend({}, this.initialConfig);
      
      $.each(this.elLk.form.serializeArray(), function () {
        if (panel.initialConfig[this.name] != this.value) {
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
    }
    
    if (d === true || f === true) {
      $.extend(true, this.initialConfig, diff);
      
      this.updatePage(diff, delayReload);
      
      return d;
    }
  },
  
  updatePage: function (diff, delayReload) {
    var data = this.imageConfig ? { config: this.imageConfig, diff: JSON.stringify(diff) } : diff;
    data.submit = 1;
    
    $.ajax({
      url:  this.elLk.form.attr('action'),
      type: this.elLk.form.attr('method'),
      data: data, 
      dataType: 'json',
      context: this,
      success: function (json) {
        if (json.updated) {
          Ensembl.EventManager.trigger('queuePageReload', this.imageConfig, !delayReload);
        } else if (json.redirect) {
          Ensembl.redirect(json.redirect);
        }
      }
    });
  },
   
  getContent: function () {
    var active = this.elLk.links.filter('.active').children('a').attr('className');
    
    this.elLk.form[active == 'active_tracks' || active == 'search_results' || active == 'favourite_tracks' ? 'addClass' : 'removeClass']('multi');
    
    if (typeof active == 'undefined') {
      active = this.elLk.links.first().addClass('active').children('a').attr('className');
    }
    
    if (active == 'search_results') {
      this.elLk.search.val(this.query);
      this.search();
    } else if (typeof active != 'undefined') {
      $('> div:not(.' + active + '), div.desc', this.elLk.form).hide();
      
      this.elLk.help.removeClass('open').attr('title', 'Click for more information');
      
      if (active == 'active_tracks') {
        $('ul.config_menu input', this.elLk.form).each(function () {
          if (this.value == 'off') {
            $(this).parent().hide().children('div.desc').hide(); // Hide the li and the description. Can't do $(this).siblings() in a chain in case there is no div.desc
          } else {
            $(this).parents('li, div.config').show();
          }
        });
      } else if (active == 'favourite_tracks') {
        $('li.fav', this.elLk.form).each(function () {
          $(this).show().parents('li, div.config').show();
        });
        
        $('li.leaf:visible:not(.fav)', this.elLk.form).hide();
      } else {
        $('div.' + active, this.elLk.form).show().find('ul.config_menu li').show();
      }
      
      this.lastQuery = false;
      this.styleTracks();
    }
  },
  
  styleTracks: function () {
    var col   = { 1: 'col1', '-1': 'col2', f: 1 };
    var multi = this.elLk.form.hasClass('multi');
    var reset;
    
    $('div.config:visible', this.elLk.form).each(function () {
      reset = true;
      
      $('li.leaf:visible', this).removeClass('col1 col2').addClass(function (i) {
        if (multi) {
          if (i === 0 && reset === true) {
            col.f = 1;
            reset = false;
          }
        } else if (!this.previousSibling) {
          col.f = 1;
        }
        
        return col[col.f *= -1];
      });
    });
  },
  
  // Filtering from the search box
  search: function () {
    var panel = this;
    var lis    = [];
    
    $('ul.config_menu', this.elLk.form).each(function () {
      var menu = $(this);
      var div  = menu.parent();
      
      if (!div[0].show) {
        div[0].show = false;
      }
      
      menu.children('li').each(function () {
        var li    = $(this);
        var html  = li.children('span:not(.controls)').html() || '';
        var match = html.match(panel.regex);
        
        if (match || li.children('div.desc').text().match(panel.regex)) {
          li.show();
          div[0].show = true;
          
          if (!match) {
            lis.push(li[0]);
          }
        } else {
          li.hide().children('div.desc').hide();
        }
        
        li = null;
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
    this.styleTracks();
    this.toggleDescription(lis, 'show');
    
    lis = null;
  },
  
  toggleDescription: function (els, action) {
    var desc, button, i;
    
    if (typeof els.length == 'undefined') {
      els = [ els ];
    }
    
    i = els.length;
    
    while (i--) {
      switch (els[i].nodeName) {
        case 'LI' : desc = $(els[i]).children('div.desc'); button = $('.menu_help', els[i]); break;
        case 'DIV': desc = $(els[i]).parent().siblings('div.desc'); button = $(els[i]); break;
        default   : return;
      }
      
      switch (action) {
        case 'hide': desc.hide(); break;
        case 'show': desc.show(); break;
        default    : desc.toggle();
      }
      
      button.toggleClass('open').attr('title', function () { return desc.is(':visible') ? 'Hide information' : 'Click for more information' });
      
      desc   = null;
      button = null;
    }
  }, 
  
  // Called when track configuration is changed on the image, rather that in the configuration panel
  externalChange: function (trackName, renderer) {
    $('input[name=' + trackName + ']', this.elLk.form).siblings('.popup_menu').children('.' + renderer).trigger('click');
    this.initialConfig[trackName].renderer = renderer;
  }
});
