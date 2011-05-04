// $Revision$

Ensembl.Panel.ImageConfig = Ensembl.Panel.Configurator.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    Ensembl.EventManager.register('changeConfiguration', this, this.externalChange);
    Ensembl.EventManager.register('changeTrackOrder',    this, this.externalOrder);
    Ensembl.EventManager.register('changeFavourite',     this, this.changeFavourite);
  },
  
  init: function () {
    var panel = this;
    var track, type, group, i, j;
    
    function setFavourite(trackName, li) {
      if (!panel.favourites[type]) {
        panel.favourites[type] = {};
      }
      
      panel.favourites[type][trackName] = [ i, li ];
    }
    
    this.base();
    
    this.elLk.search         = $('.configuration_search_text', this.el);
    this.elLk.searchResults  = $('a.search_results', this.elLk.links);
    this.elLk.configDivs     = $('div.config', this.elLk.form);
    this.elLk.configs        = $('ul.config_menu > li', this.elLk.configDivs);
    this.elLk.tracks         = this.elLk.configs.filter('.track');
    this.elLk.help           = $('.menu_help',  this.elLk.configDivs);
    this.elLk.menus          = $('.popup_menu', this.elLk.configDivs);
    this.elLk.favouritesMsg  = this.elLk.configDivs.filter('.favourite_tracks');
    this.elLk.trackOrder     = this.elLk.configDivs.filter('.track_order');
    this.elLk.trackOrderList = $('ul.config_menu', this.elLk.trackOrder);
    
    this.imageConfig        = $('input[name=config]', this.elLk.form).val();
    this.sortable           = !!this.elLk.trackOrder.length;
    this.trackReorder       = false;
    this.lastQuery          = false;
    this.populated          = {};
    this.favourites         = {};
    this.externalFavourites = {};
    
    for (type in this.params.tracks) {
      group = this.params.tracks[type];
      i     = group.length;
      
      while (i--) {
        for (j in group[i]) {
          track = group[i][j];
          
          if (track[1].match('config_menu')) {
            $('li.fav', track[1]).each(function () {
              setFavourite($(this).children('input.track_name')[0].name, this);
            });
          } else if (track[2]) {
            setFavourite(track[0], track[1]);
          }
        }
      }
    }
    
    this.elLk.tracks.each(function () {
      var input = $('input.track_name', this)[0];
      panel.initialConfig[input.name] = { renderer: input.value, favourite: $(this).hasClass('fav') };
      input = null;
    });
    
    if (this.sortable) {
      this.makeSortable();
    }
    
    // Must die for live events here because if the panel is recreated (eg with reset button), the live events access the old panel variable.
    $('.menu_help', this.elLk.configDivs).die().live('click', function () { panel.toggleDescription(this); });
    
    $('.favourite', this.elLk.configDivs).die().live('click', function () {
      Ensembl.EventManager.trigger(
        'changeFavourite', 
        $(this).parent().siblings('input.track_name')[0].name,
        $(this).parents('li.track').hasClass('fav') ? 0 : 1,
        $(this).parents('div.config')[0].className.replace(/config /, ''),
        panel.id
      );
    });
    
    // Popup menus - displaying
    $('.menu_option', this.elLk.configDivs).die().live('click', function () {
      var menu = $(this).siblings('.popup_menu');
      
      if (menu.children().length === 2 && !$(this).parent().hasClass('select_all')) {
        menu.children(':not(.' + $(this).siblings('input.track_name').val() + ')').trigger('click');
      } else {
        panel.elLk.menus.filter(':visible').not(menu).hide();
        menu.toggle();
      }
      
      menu = null;
    });
    
    // Popup menus - setting values
    $('.popup_menu li', this.elLk.configDivs).die().live('click', function () {
      var li      = $(this);
      var img     = li.children('img');
      var menu    = li.parents('.popup_menu');
      var track   = menu.parent();
      var val     = li.attr('className');
      var link    = panel.elLk.links.children('a.' + img.attr('className'));
      var label   = link.html().split(/\b/);
      var updated = {};
      
      if (track.hasClass('select_all')) {
        track = track.next().find('li.track');
        
        if (val === 'all_on') {
          // First li is off, so use the second (index 1) as default on setting.
          track.find('li:eq(1)').each(function () {
            var text = $(this).text();
            
            $(this).parent().siblings('img.menu_option:not(.select_all)').attr({ 
              src:   '/i/render/' + this.className + '.gif', 
              alt:   text,
              title: text
            }).siblings('input.track_name').attr('newVal', this.className).parent()[this.className === 'off' ? 'removeClass' : 'addClass']('on');
          });
        }
      }
      
      track.children('input.track_name').each(function () {
        var input = $(this);
        
        if (input.val() === 'off' ^ val === 'off') {
          label[1] = parseInt(label[1], 10) + (val === 'off' ? -1 : 1);
        }
        
        input.val(input.attr('newVal') || val).removeAttr('newVal');
        
        updated[this.name] = [ this.value, li.text() ];
        
        input = null;
      });
      
      if (val !== 'all_on') {
        track.children('img.menu_option').attr({ 
          src:   '/i/render/' + val + '.gif', 
          alt:   li.text(),
          title: li.text()
        }).end()[val === 'off' ? 'removeClass' : 'addClass']('on');
      }
      
      label = label.join('');
      link.attr('title', label).html(label);
      menu.hide();
      
      if (panel.sortable) {
        $.each(updated, function (trackName, attrs) {
          $.each([panel.elLk.tracks, panel.elLk.trackOrderList.children()], function () {
            $(this).filter('.' + trackName).not(li).children('img.menu_option').attr({ 
              src:   '/i/render/' + attrs[0] + '.gif', 
              alt:   attrs[1],
              title: attrs[1]
            }).siblings('input.track_name').val(attrs[0]).parent()[attrs[0] === 'off' ? 'removeClass' : 'addClass']('on');
          });
        });
      }
      
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
        
        if (this.value !== panel.lastQuery) {
          if (panel.searchTimer) {
            clearTimeout(panel.searchTimer);
          }
          
          panel.query = this.value;
          panel.regex = new RegExp(this.value, 'i');
          
          panel.searchTimer = setTimeout(function () {
            panel.elLk.links.removeClass('active');
            panel.elLk.searchResults.removeClass('disabled').parent().addClass('active');
            panel.elLk.form.addClass('multi');
            panel.search(); 
          }, 250);
        }
      },
      focus: function () {
        this.value = '';
        this.style.color = '#000';
      },
      blur: function () {
        if (!this.value) {
          this.value = 'Find a track';
          this.style.color = '#999';
        }
      }
    });
    
    // Header on search results and active tracks sections will act like the links on the left
    $('.config_header', this.elLk.configDivs).bind('click', function () {
      var link = $(this).parent().attr('className').replace(/\s*config\s*/, '');
      $('a.' + link, panel.elLk.links).trigger('click');
    });
    
    $('select.species', this.el).bind('change', function () {
      if (this.value) {
        var species = this.selectedIndex === 0 ? '' : '_' + this.value.split('/')[1];
        var id      = 'modal_config_' + (panel.imageConfig + species).toLowerCase();
        var change  = $('#' + id);
        
        panel.hide();
        
        if (!change.length) {
          change = $('<div>', { id: id, className: 'modal_content js_panel active', html: '<div class="spinner">Loading Content</div>' });
          Ensembl.EventManager.trigger('addModalContent', change, this.value, id, 'modal_config_' + panel.imageConfig.toLowerCase());
        } else {
          change.find('select.species')[0].selectedIndex = this.selectedIndex;
          change.addClass('active').show();
        }
        
        $(panel.el).removeClass('active');
        Ensembl.EventManager.trigger('setActivePanel', id);
        panel.updateConfiguration(true);
        
        change = null;
      }
    });
    
    this.getContent();
  },
  
  addTracks: function (type) {
    if (this.populated[type]) {
      return;
    }
    
    var panel    = this;
    var tracks   = this.params.tracks[type];
    var configs  = this.elLk.configDivs.filter('.' + type).find('ul.config_menu');
    var existing = [];
    var i        = tracks.length;
    var j, track, li;
    
    function setConfig(trackName) {
      if (!panel.initialConfig[trackName]) {
        panel.initialConfig[trackName] = { renderer: 'off', favourite: !!panel.favourites[type] && panel.favourites[type][trackName] };
      }
      
      panel.externalFavourite(trackName, li);
    }
    
    configs.each(function (k) {
      if (!existing[k]) {
        existing[k] = {};
      }
      
      $(this).children().each(function () { existing[k][$('input.track_name', this)[0].name] = this; }).detach();
    });
    
    while (i--) {
      for (j in tracks[i]) {
        track = tracks[i][j];
        li    = $(existing[i][track[0]] || track[1]);
        
        if (track[1].match('config_menu')) {
          $('input.track_name', track[1]).each(function () {
            if (existing[i][this.name]) {
              li.find('.' + this.name).replaceWith(existing[i][this.name]);
            } else {
              setConfig(this.name);
            }
          });
        } else {
          setConfig(track[0]);
        }
        
        $(configs[i]).append(li);
      }
    }
    
    this.updateElLk();
    this.populated[type] = 1;
  },
  
  updateElLk: function () {
    this.elLk.help    = $('.menu_help',        this.elLk.configDivs);
    this.elLk.menus   = $('.popup_menu',       this.elLk.configDivs);
    this.elLk.configs = $('.config_menu > li', this.elLk.configDivs);
    this.elLk.tracks  = this.elLk.configs.filter('.track');
  },
  
  show: function (active) {
    this.elLk.menus.hide();
    this.base();
  },
  
  getContent: function () {
    var panel  = this;
    var active = this.elLk.links.filter('.active').children('a')[0];
    
    function favouriteTracks() {
      var added, trackName, li, favs, type;
      var external = $.extend({}, panel.externalFavourites);
      
      for (trackName in external) {
        if (external[trackName]) {
          panel.addTracks(external[trackName][1]);
        } else {
          delete panel.favourites[external[trackName][1]][trackName];
        }
      }
      
      for (type in panel.favourites) {
        for (trackName in panel.favourites[type]) {
         li = panel.elLk.tracks.filter('.' + trackName);
          
          if (!li.length) {
            li = $(panel.favourites[type][trackName][1]).appendTo(panel.elLk.configDivs.filter('.' + type).children('ul.config_menu').eq(panel.favourites[type][trackName][0]));
            panel.initialConfig[trackName] = { renderer: 'off', favourite: 1 };
            added = true;
          }
          
          li = null;
        }
      }
      
      if (added) {
        panel.updateElLk();
      }
      
      favs = panel.elLk.configs.hide().filter('.track.fav').show().each(function () { $(this).show().parents('li, div.config').show(); }).length;
      panel.elLk.favouritesMsg[favs ? 'hide' : 'show']();
    }
    
    function trackOrder() {
      var ul     = panel.elLk.trackOrderList;
      var lis    = ul.children();
      var strand = [ 'f', 'r' ];
      var tracks = [];
      var i, trackName, order, li;
      
      panel.elLk.tracks.filter('.on').each(function () {
        trackName = $(this).children('input.track_name')[0].name;
        order     = panel.params.order[trackName];
        
        if (typeof order !== 'undefined' && !lis.filter('.' + trackName).length) {
          tracks.push([ order, $(this), trackName ]);
          return;
        }
        
        for (i in strand) {
          order = panel.params.order[trackName + '.' + strand[i]];
          
          if (typeof order !== 'undefined' && !lis.filter('.' + trackName + '.' + strand[i]).length) {
            tracks.push([ order, $(this), trackName + ' ' + strand[i], '<div class="strand" title="' + (strand[i] === 'f' ? 'Forward' : 'Reverse') + ' strand"></div>' ]);
          }
        }
      });
      
      tracks = tracks.sort(function (a, b) { return a[0] - b[0]; });
      
      if (lis.length) {
        $.each(tracks, function () {
          i  = lis.length;
          li = this[1].clone(true).data('order', this[0]).removeClass().addClass(this[2]).children('.controls').prepend(this[3]).end();
          
          while (i--) {
            if ($(lis[i]).data('order') < this[0]) {
              li.insertAfter(lis[i]);
              break;
            }
          }
          
          if (i === -1) {
            li.insertBefore(lis[0]);
          }
          
          li = null;
        });
      } else {
        $.each(tracks, function () {
          this[1].clone(true).data('order', this[0]).removeClass().addClass(this[2]).children('.controls').prepend(this[3]).end().appendTo(ul).children('.popup_menu').hide();
        });
      }
      
      if (tracks.length) {
        panel.updateElLk();
      }
      
      panel.elLk.trackOrder.show().find('ul.config_menu li').filter(function () { return this.style.display === 'none'; }).show();
      
      ul  = null;
      lis = null;
    }
    
    if (active.rel === 'multi' ^ this.elLk.form.hasClass('multi')) {
      this.elLk.form[active.rel === 'multi' ? 'addClass' : 'removeClass']('multi');
    }
    
    this.elLk.configDivs.filter(function () { return this.style.display !== 'none'; }).hide();
    this.elLk.help.filter('.open').removeClass('open').attr('title', 'Click for more information').parent().siblings('div.desc').hide();
    
    this.lastQuery = false;
    
    active = active.className;    
    
    switch (active) {
      case 'search_results':
        this.elLk.search.val(this.query);
        this.search();
        return;
        
      case 'active_tracks':
        this.elLk.configs.hide().filter('.on').show().parents('li, div.config').show();
        break;
      
      case 'favourite_tracks':
        favouriteTracks();
        break;
      
      case 'track_order':
        trackOrder();
        return;
        
      default:
        this.addTracks(active);
        this.elLk.configDivs.filter('.' + active).show().find('ul.config_menu li').filter(function () { return this.style.display === 'none'; }).show();
    }
    
    this.styleTracks();
  },
  
  updateConfiguration: function (delayReload) {
    if ($('input.invalid', this.elLk.form).length) {
      return;
    }
    
    var panel = this;
    var d     = false;
    var diff  = {};
    
    this.elLk.tracks.each(function () {
      var fav       = $(this).hasClass('fav');
      var input     = $('input.track_name', this)[0];
      var trackName = input.name;
      
      var favourite = !panel.initialConfig[trackName].favourite &&  fav ? 1 : // Making a track a favourite
                       panel.initialConfig[trackName].favourite && !fav ? 0 : // Making a track not a favourite
                       false;
      
      if (panel.initialConfig[trackName].renderer !== input.value) {
        diff[trackName] = { renderer: input.value };
        d = true;
      }
      
      if (favourite !== false) {
        diff[trackName] = diff[trackName] || {};
        diff[trackName].favourite = favourite;
        d = true;
      }
      
      input = null;
    });
    
    if (this.trackReorder !== false) {
      diff.track_order = this.trackReorder;
      this.trackReorder = false;
      d = true;
    }
    
    if (d === true) {
      $.extend(true, this.initialConfig, diff);
      
      this.updatePage({ config: this.imageConfig, diff: JSON.stringify(diff) }, delayReload);
      
      if (this.params.reset && diff.track_order) {
        d = false;
        this.params.reset = false;
      }
      
      return d;
    }
  },
  
  makeSortable: function () {
    var panel = this;
    
    for (var i in this.params.order) {
      this.params.order[i] = parseFloat(this.params.order[i], 10);
    }
    
    this.elLk.trackOrderList.sortable({
      axis: 'y',
      handle: 'span.menu_option',
      containment: 'parent',
      update: function (e, ui) {
        var track = ui.item[0].className.replace(' ', '.');
        var p     = ui.item.prev().data('order') || 0;
        var n     = ui.item.next().data('order') || 0;
        var o     = p || n;
        var order;
        
        if (Math.floor(n) === Math.floor(p)) {
          order = p + (n - p) / 2;
        } else {
          order = o + (p ? 1 : -1) * (Math.round(o) - o || 1) / 2;
        }
        
        if (panel.trackReorder === false) {
          panel.trackReorder = {};
        }
        
        panel.trackReorder[track] = order;
        
        ui.item.data('order', order);
        
        if (panel.params.reset !== 'track_order') {
          Ensembl.EventManager.triggerSpecific('changeTrackOrder', panel.imageConfig, track, order);
        }
      }
    });
  },
  
  styleTracks: function () {
    var reset = true;
    var col   = { 1: 'col1', '-1': 'col2', f: 1 };
    var style = this.elLk.form.hasClass('multi') ? function (i) {
      if (i === 0 && reset === true) {
        col.f = 1;
        reset = false;
      }
      
      return col[col.f *= -1];
    } : function (i) {
      if (!this.previousSibling) {
        col.f = 1;
      }
      
      return col[col.f *= -1];
    };
    
    // Filtering on this.style.display !== 'none' is faster than doing a :visible selector, particularly in IE7/8
    this.elLk.configDivs.filter(function () { return this.style.display !== 'none'; }).each(function () {
      reset = true;
      $('li.track', this).filter(function () { return this.style.display !== 'none'; }).removeClass('col1 col2').addClass(style);
    });
  },
  
  // Filtering from the search box
  search: function () {
    var panel = this;
    var lis   = [];
    var added = false;
    var div, show, menu, tracks, track, trackName, i, j, match, type;
    
    function search(n, li) {
      match = li.children('span.menu_option').text().match(panel.regex);
      
      if (match || li.children('div.desc').text().match(panel.regex)) {
        if (panel.initialConfig[n]) {
          li.show();
        } else {
          li = menu.append(li).find('li.' + n);
          panel.initialConfig[n] = { renderer: 'off', favourite: !!panel.favourites[type] && panel.favourites[type][n] };
          panel.externalFavourite(n, li);
          added = true;
        }
        
        show = true;
        
        if (!match) {
          lis.push(li[0]);
        }
      } else if (panel.initialConfig[trackName]) {
        li.hide().find('div.desc').hide();
      }
    }
    
    for (type in this.params.tracks) {
      div    = this.elLk.configDivs.filter('.' + type);
      show   = false;
      tracks = this.params.tracks[type];
      i      = tracks.length;
      
      while (i--) {
        menu = div.children('ul.config_menu').eq(i);
        
        for (j in tracks[i]) {
          track     = tracks[i][j];
          trackName = track[0];
          
          if (track[1].match('config_menu')) {
            if (track[1].match(this.regex)) {
              $('input.track_name', track[1]).each(function () {
                search(this.name, panel.initialConfig[this.name] ? menu.find('li.' + this.name) : $(this).parent());
              });
            } else {
              $('input.track_name', track[1]).each(function () {
                menu.find('li.' + this.name).hide();
              });
            }
          } else {
            search(trackName, this.initialConfig[trackName] ? menu.find('li.' + trackName) : $(track[1]));
          }
        }
        
        menu = null;
      }
      
      div[show === true ? 'show' : 'hide']();
      div = null;
    }
    
    if (added) {
      this.updateElLk();
    }
    
    this.lastQuery = this.query;
    this.styleTracks();
    this.toggleDescription(lis, 'show');
    
    lis = null;
  },
  
  toggleDescription: function (els, action) {
    var desc, button, i;
    
    if (typeof els.length === 'undefined') {
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
      
      button.toggleClass('open').attr('title', function () { return desc.is(':visible') ? 'Hide information' : 'Click for more information'; });
      
      desc   = null;
      button = null;
    }
  }, 
  
  changeFavourite: function (trackName, selected, type, id) {
    var li = this.elLk.tracks.filter('.' + trackName).toggleClass('fav');
    var div;
    
    if (this.sortable) {
      this.elLk.trackOrderList.children('.' + trackName).toggleClass('fav');
    }
    
    if (this.elLk.links.filter('.active').children('a')[0].className === 'favourite_tracks') {
      li.hide(); // Always hide, since the only way a click can come here is from a selected track
      div = li.parents('div.config');
      
      if (!div.find('li:visible').length) {
        div.hide();
      }
      
      if (!this.elLk.tracks.filter('.fav').length) {
        this.elLk.favouritesMsg.show();
      }
    }
    
    if (this.id !== id) {
      if (type) {
        this.externalFavourites[trackName] = [ selected, type ];
      }
      
      if (this.initialConfig[trackName]) {
        this.initialConfig[trackName].favourite = selected;
      }
    }
    
    li  = null;
    div = null;
  },
  
  externalFavourite: function (trackName, el) {
    if (typeof this.externalFavourites[trackName] !== 'undefined') {
      this.initialConfig[trackName].favourite = this.externalFavourites[trackName][0];
      
      if (el.hasClass('fav') !== this.initialConfig[trackName].favourite) {
        el[this.initialConfig[trackName].favourite ? 'addClass' : 'removeClass']('fav');
      }
      
      delete this.externalFavourites[trackName];
    }
  },
  
  // Called when track configuration is changed on the image, rather that in the configuration panel
  externalChange: function (trackName, renderer) {
    this.elLk.tracks.filter('.' + trackName).find('.popup_menu .' + renderer).trigger('click');
    this.initialConfig[trackName].renderer = renderer;
  },
  
  // Called when track order is changed on the image
  externalOrder: function (trackName, order) {
    var lis = this.elLk.trackOrderList.children();
    var i   = lis.length;
    var li;
    
    if (i) {
      li = lis.filter('.' + trackName).detach();
      
      while (i--) {
        if ($(lis[i]).data('order') < order) {
          li.insertAfter(lis[i]);
          break;
        }
      }
      
      if (i === -1) {
        li.insertBefore(lis[0]);
      }
    } else {
      this.params.order[trackName] = order;
    }
    
    lis = null;
    li  = null;
  }
});
