// $Revision$

Ensembl.Panel.Configurator = Ensembl.Panel.ModalContent.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    Ensembl.EventManager.register('updateConfiguration', this, this.updateConfiguration);
    Ensembl.EventManager.register('showConfiguration',   this, this.show);
    Ensembl.EventManager.register('changeConfiguration', this, this.externalChange);
    Ensembl.EventManager.register('changeTrackOrder',    this, this.externalOrder);
    Ensembl.EventManager.register('changeFavourite',     this, this.changeFavourite);
    Ensembl.EventManager.register('syncViewConfig',      this, this.syncViewConfig);
    Ensembl.EventManager.register('modalHide',           this, this.saveAsHide);
    Ensembl.EventManager.register('updateSavedConfig',   this, this.updateSavedConfig);
    Ensembl.EventManager.register('activateConfig',      this, this.activateConfig);
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
    
    if (this.params.hash) {
      this.elLk.links.removeClass('active').children('.' + this.params.hash).parent().addClass('active');
      delete this.params.hash;
    }
    
    this.elLk.form              = $('form.configuration', this.el);
    this.elLk.headers           = $('h1', this.el);
    this.elLk.search            = $('.configuration_search_text', this.el);
    this.elLk.searchResults     = $('a.search_results', this.elLk.links);
    this.elLk.configDivs        = $('div.config', this.elLk.form);
    this.elLk.configMenus       = this.elLk.configDivs.find('.config_menu');
    this.elLk.configs           = this.elLk.configMenus.children('li');
    this.elLk.tracks            = this.elLk.configs.filter('.track');
    this.elLk.favouritesMsg     = this.elLk.configDivs.filter('.favourite_tracks');
    this.elLk.noSearchResults   = this.elLk.configDivs.filter('.no_search');
    this.elLk.trackOrder        = this.elLk.configDivs.filter('.track_order');
    this.elLk.trackOrderList    = $('ul.config_menu', this.elLk.trackOrder);
    this.elLk.viewConfigs       = this.elLk.configDivs.filter('.view_config');
    this.elLk.viewConfigInputs  = $(':input:not([name=select_all])', this.elLk.viewConfigs);
    this.elLk.imageConfigExtras = $('.image_config_notes, .configuration_search', this.el);
    this.elLk.saveAs            = $('.config_save_as', this.el).insertAfter(this.el); // IE 6 and 7 are stupid and can't deal with z-index correctly
    this.elLk.saveAsClose       = $('.close', this.elLk.saveAs);
    this.elLk.saveAsInputs      = $('.name, .desc, .default, .existing', this.elLk.saveAs);
    this.elLk.saveAsRequired    = this.elLk.saveAsInputs.filter('.name, .existing');
    this.elLk.existingConfigs   = this.elLk.saveAsInputs.filter('.existing');
    this.elLk.saveAsSubmit      = $('.fbutton', this.elLk.saveAs);
    this.elLk.saveAsBg          = this.el.siblings('#config_save_as_bg');
    this.elLk.modalClose        = this.el.siblings('.modal_title').children('.modal_close');
    this.elLk.menus             = $();
    this.elLk.help              = $();
    
    this.component          = $('input.component', this.elLk.form).val();
    this.sortable           = !!this.elLk.trackOrder.length;
    this.trackReorder       = false;
    this.lastQuery          = false;
    this.populated          = {};
    this.favourites         = {};
    this.externalFavourites = {};
    this.imageConfig        = {};
    this.viewConfig         = {};
    this.subPanels          = [];
    this.searchCache        = [];
    
    // Move user data to below the multi entries (active tracks, favourites, search)
    if (this.elLk.configDivs.first().not('.move_to_top').length) {
      this.elLk.links.filter('.move_to_top').insertAfter(this.elLk.links.has('[rel=multi]').last());
      this.elLk.configDivs.filter('.move_to_top').insertBefore(this.elLk.configDivs.first());
    }
    
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
      var input  = $('input.track_name', this)[0];
      var type   = $('.popup_menu img:not(.close)', this)[0].className;
      var subset = this.className.match(/\s*subset_(\w+)\s*/) || false;
      
      $(this).data('links', [
        'a.' + type, 
        'a.' + (subset ? subset[1] : type + '-' + $(this).parents('.subset').attr('class').replace(/subset|active|first|\s/g, ''))
      ].join(', '));
      
      panel.imageConfig[input.name] = { renderer: input.value, favourite: $(this).hasClass('fav'), el: $(this) };
      
      input = null;
    });
    
    this.elLk.viewConfigInputs.each(function () {
      panel.viewConfig[this.name] = this.type === 'checkbox' ? this.checked ? this.value : 'off' : this.type === 'select-multiple' ? $('option:selected', this).map(function () { return this.value; }).toArray() : this.value;
    });
    
    if (this.sortable) {
      this.makeSortable();
    }
    
    this.elLk.configDivs.on('click', 'ul.config_menu > li.track', function (e) {
      if (e.target === this) {
        $(this).children('img.menu_option').trigger('click');
      }
      
      return e.target.nodeName === 'A';
    });
    
    // Popup menus - displaying
    this.elLk.configDivs.on('click', '.menu_option', function () {
      var el       = $(this);
      var menu     = el.siblings('.popup_menu');
      var current  = menu.find('span.current');
      var selected = el.siblings('input.track_name').val();
      
      if (menu.children().length === 2 && !el.parent().hasClass('select_all')) {
        menu.children(':not(.' + selected + ')').trigger('click');
      } else {
        panel.elLk.menus.filter(':visible').not(menu.toggle()).hide();        
        panel.elLk.menus = panel.elLk.menus.add(menu).filter(function () { return this.style.display !== 'none'; });
      }
      
      if (current.parent().attr('class') !== selected) {
        menu.find('span.current').removeClass('current').siblings('img.tick').detach().insertBefore(menu.find('.' + selected + ' span').addClass('current'));
      }
      
      menu = current = el = null;
      
      return false;
    });
    
    // Popup menus - setting values
    this.elLk.configDivs.on('click', '.popup_menu li:not(.header)', function () {
      var li     = $(this);
      var val    = this.className;
      var menu   = li.parents('.popup_menu');
      var subset = val.match(/\s*subset_(\w+)\s*/) || false;
      
      if (subset) {
        menu.hide();
        panel.elLk.links.children('a.' + subset[1]).trigger('click');
        return false;
      }
      
      var img     = li.children('img');
      var track   = menu.parent();
      var change  = 0;
      var updated = {};
      
      if (track.hasClass('select_all')) {
        track = track.next().find('li.track:not(.hidden)');
        
        if (val === 'all_on') {
          // First li is off, so use the second (index 1) as default on setting.
          track.find('li:not(.header):eq(1)').each(function () {
            var text = $(this).text();
            
            $(this).parent().siblings('img.menu_option:not(.select_all)').attr({ 
              src:   '/i/render/' + this.className + '.gif', 
              alt:   text,
              title: text
            }).siblings('input.track_name').data('newVal', this.className).parent()[this.className === 'off' ? 'removeClass' : 'addClass']('on');
          });
        }
      }
      
      track.children('input.track_name').each(function () {
        var input = $(this);
        
        if (input.val() === 'off' ^ val === 'off') {
          change += (val === 'off' ? -1 : 1);
        }
        
        input.val(input.data('newVal') || val).removeData('newVal');
        
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
      
      panel.elLk.links.children(track.data('links')).siblings('.count').children('.on').html(function (i, html) {
        return parseInt(html, 10) + change;
      });
      
      menu.hide();
      
      $.each(updated, function (trackName, attrs) {
        panel.imageConfig[trackName].el.add(panel.imageConfig[trackName].linked).not(li).children('img.menu_option').attr({ 
          src:   '/i/render/' + attrs[0] + '.gif', 
          alt:   attrs[1],
          title: attrs[1]
        }).siblings('input.track_name').val(attrs[0]).parent()[attrs[0] === 'off' ? 'removeClass' : 'addClass']('on');
      });
      
      menu = track = img = li = null;
      
      return false;
    });
    
    this.elLk.configDivs.on('click', '.popup_menu .header .close', function () {
      $(this).parents('.popup_menu').hide();
      return false;
    });
    
    // Header on search results and active tracks sections will act like the links on the left
    this.elLk.configDivs.on('click', '.config_header', function () {
      var link = $(this).parent().attr('class').replace(/\s*config\s*/, '');
      $('a.' + link, panel.elLk.links).trigger('click');
      return false;
    });
    
    this.elLk.configDivs.on('click', '.favourite', function () {
      Ensembl.EventManager.trigger(
        'changeFavourite', 
        $(this).parent().siblings('input.track_name')[0].name,
        $(this).parents('li.track').hasClass('fav') ? 0 : 1,
        $(this).parents('div.config')[0].className.replace(/config /, ''),
        panel.id
      );
      
      return false;
    });
    
    this.elLk.configDivs.on('click', '.menu_help', function () {
      panel.toggleDescription(this);
      return false;
    });
    
    
    this.elLk.viewConfigs.on('change', ':input', function () {
      var value, attr;
      
      if (this.type === 'checkbox') {
        value = this.checked;
        attr  = 'checked';
      } else {
        value = this.value;
        attr  = 'value';
      }
      
      Ensembl.EventManager.trigger('syncViewConfig', panel.id, $(this).parents('.config')[0].className.replace(/ /g, '.'), this.name, attr, value);
    });
    
    this.elLk.search.on({
      keyup: function () {
        var value = this.value.toLowerCase(); 
        
        if (this.value.length < 2) {
          panel.lastQuery = value;
        }
        
        if (value !== panel.lastQuery) {
          if (panel.searchTimer) {
            clearTimeout(panel.searchTimer);
          }
          
          panel.query = value;
          
          panel.searchTimer = setTimeout(function () {
            panel.elLk.links.removeClass('active');
            panel.elLk.searchResults.removeClass('disabled').parent().addClass('active');
            panel.elLk.headers.hide().filter('.search_results').show();
            panel.elLk.imageConfigExtras.show();
            panel.elLk.form.addClass('multi').removeClass('single');
            panel.search(); 
          }, 250);
        }
      },
      focus: function () {
        if (this.value === this.defaultValue) {
          this.value = '';
        }
        
        this.style.color = '#000';
      },
      blur: function () {
        if (!this.value) {
          this.value = 'Find a track';
          this.style.color = '#999';
        }
      }
    });
    
    $('select.species', this.el).on('change', function () {
      if (this.value) {
        var species = this.value.split('/')[1];
        var id      = 'modal_config_' + (panel.component + (species === Ensembl.species ? '' : '_' + species)).toLowerCase();
        var change  = $('#' + id);
        
        panel.hide();
        
        if (!change.length || !change.children().length) {
          Ensembl.EventManager.trigger('updateConfiguration', true);
          change = change.length ? false : $('<div>', { id: id, 'class': 'modal_content js_panel active', html: '<div class="spinner">Loading Content</div>' });
          Ensembl.EventManager.trigger('addModalContent', change, this.value, id, 'modal_config_' + panel.component.toLowerCase());
        } else {
          change.find('select.species')[0].selectedIndex = this.selectedIndex;
          change.addClass('active').show();
        }
        
        $(panel.el).removeClass('active');
        Ensembl.EventManager.trigger('setActivePanel', id);
        panel.updateConfiguration(true);
        
        change = null;
      }
    }).parent().prependTo(this.el.find('.nav')); // Move to above the nav
    
    $('.save_configuration', this.el).on('click', function () {
      panel.elLk.saveAsInputs.each(function () {
        var el = $(this);
        
        if (el.hasClass('default')) {
          el.prop('checked', true);
        } else {
          el.val('');
        }
        
        el = null;
      });
      
      panel.el.scrollTop(0);
      panel.elLk.saveAsSubmit.prop('disabled', true).addClass('disabled');
      panel.elLk.saveAs.show().css('marginTop', (panel.elLk.saveAs.height() / -2) - 18);
      panel.elLk.saveAsBg.show();
      panel.elLk.modalClose.hide();
      
      return false;
    });
    
    this.elLk.saveAsClose.on('click', function () { panel.saveAsHide(); });
    
    function saveAsState() {
      var disabled = !$.grep(panel.elLk.saveAsRequired.not('.disabled'), function (el) { return el.value; }).length;
      panel.elLk.saveAsSubmit.prop('disabled', disabled)[disabled ? 'addClass' : 'removeClass']('disabled');
    }
    
    this.elLk.saveAsInputs.filter('.name').on('keyup', saveAsState);
    this.elLk.existingConfigs.on('change', saveAsState);
    
    this.elLk.saveAsSubmit.on('click', function () {
      var saveAs = { save_as: 1 };
      
      $.each($(this).parents('form').serializeArray(), function () { saveAs[this.name] = this.value.replace(/<[^>]+>/g, ''); });
      
      if (saveAs.name || saveAs.overwrite) {
        panel.updateConfiguration(true, saveAs);
        panel.saveAsHide();
      }
    });
    
    this.getContent();
  },
  
  addTracks: function (type) {
    if (this.populated[type] || !this.params.tracks[type]) {
      return;
    }
    
    var tracks      = this.params.tracks[type];
    var configs     = this.elLk.configDivs.filter('.' + type).find('ul.config_menu').each(function (i) { $.data(this, 'index', i); });
    var i           = tracks.length;
    var configMenus = $();
    var data        = { imageConfigs: [], html: [], submenu: [] };
    var j, track, li, ul, lis, link, subset;
    
    while (i--) {
      j  = tracks[i].length;
      ul = configs.eq(i);
      
      data.html[i]         = [];
      data.imageConfigs[i] = [];
      data.submenu[i]      = false;
      
      while (j--) {
        track = tracks[i][j];
        
        if (this.imageConfig[track[0]]) {
          ul.children('.' + track[0]).remove();
          data.html[i].unshift(this.imageConfig[track[0]].el[0].outerHTML || [ '<li class="', this.imageConfig[track[0]].el[0].className , '">', this.imageConfig[track[0]].el[0].innerHTML, '</li>' ].join(''));
        } else {
          data.html[i].unshift(track[1]);
        }
        
        data.imageConfigs[i][j] = track[0];
      }
      
      if (ul[0].innerHTML) {
        ul.children().each(function () {
          data.html[i].push('<li class="', this.className, '">');
          
          $.each(this.childNodes, function () {
            var index = $.data(this, 'index');
            var innerHTML;
            
            if (typeof index === 'undefined') {
              innerHTML = this.innerHTML;
            } else {
              innerHTML        = data.html[index];
              data.html[index] = '';
              data.submenu[i]  = true;
            }
            
            data.html[i].push('<', this.nodeName, ' class="', this.className , '">', innerHTML, '</', this.nodeName, '>');
          });
          
          data.html[i].push('</li>');
        });
        
        if (data.submenu[i]) {
          configMenus.push(ul[0]);
        }
      }
      
      data.html[i] = data.html[i].join('');
    }
    
    i = tracks.length;
    
    while (i--) {
      if (data.html[i]) {
        configs[i].innerHTML = data.html[i];
      }
    }
    
    // must loop forwards here, since parent uls will write the content of child uls 
    for (i = 0; i < tracks.length; i++) {
      ul   = configs.eq(i);
      j    = data.imageConfigs[i].length;
      link = ul.parents('.subset').attr('class').replace(/subset|active|first|\s/g, '');
      lis  = ul.children();
      
      if (data.submenu[i]) {
        lis.children('ul.config_menu').each(function (k) { configs[i + k + 1] = this; }); // alter the configs entry for all child uls after adding the content
      }
      
      lis.filter('.track').each(function () {
        subset = this.className.match(/\s*subset_(\w+)\s*/) || false;
        
        $.data(this, 'links', [
          'a.' + type,
          'a.' + (subset ? subset[1] : type + '-' + link) 
        ].join(', '));
      });
      
      while (j--) {
        li    = lis.eq(j);
        track = data.imageConfigs[i][j];
        
        if (this.imageConfig[track]) {
          this.imageConfig[track].el = li;
        } else {
          this.imageConfig[track] = { renderer: 'off', favourite: !!this.favourites[type] && this.favourites[type][track], el: li };
        }
        
        this.externalFavourite(track, li);
      }
    }
    
    this.updateElLk(type, configMenus);
    this.populated[type] = 1;
    
    configs = configMenus = ul = lis = li = null;
  },
  
  updateElLk: function (arg, configMenus) {
    if (configMenus && configMenus.length) {
      this.elLk.configMenus = this.elLk.configMenus.add(configMenus.find('ul.config_menu')).filter(function () { return $(this).parents('body').length; });
    }
    
    if (arg) {
      this.elLk.configs = this.elLk.configs.add(typeof arg === 'string' ? this.elLk.configMenus.filter('.' + arg).children('li') : arg).filter(function () { return this.parentNode && this.parentNode.nodeName === 'UL'; });
    } else {
      this.elLk.configs = this.elLk.configMenus.children('li');
    }
    
    this.elLk.tracks = this.elLk.configs.filter('.track');
  },
  
  show: function (active) {
    this.elLk.menus.hide();
    
    if (active) {
      this.elLk.links.removeClass('active').find('.' + active).parent().addClass('active');
    }
    
    this.base();
    this.getContent();
  },
  
  getContent: function () {
    var panel  = this;
    var active = this.elLk.links.filter('.active').children('a')[0];
    var url, configDiv, subset;
    
    function favouriteTracks() {
      var trackName, li, favs, type;
      var external = $.extend({}, panel.externalFavourites);
      var added    = [];
      
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
            li = $(panel.favourites[type][trackName][1]).appendTo(panel.elLk.configDivs.filter('.' + type).find('ul.config_menu').eq(panel.favourites[type][trackName][0]));
            li.data('links', [
              'a.' + type,
              'a.' + (subset ? subset[1] : type + '-' + li.parents('.subset').attr('class').replace(/subset|active|first|\s/g, '')) 
            ].join(', '));
            
            panel.imageConfig[trackName] = { renderer: 'off', favourite: 1, el: li };
            added.push(li[0]);
          }
          
          li = null;
        }
      }
      
      if (added.length) {
        panel.updateElLk(added);
      }
      
      favs = panel.elLk.configs.hide().filter('.track.fav').show().each(function () { $(this).show().parents('li, div.subset, div.config').show(); }).length;
      
      panel.elLk.favouritesMsg[favs ? 'hide' : 'show']();
    }
    
    function trackOrder() {
      var ul     = panel.elLk.trackOrderList;
      var lis    = ul.children();
      var strand = [ 'f', 'r' ];
      var tracks = [];
      var i, trackName, order, li;
      
      panel.elLk.tracks.filter('.on').each(function () {
        var el    = $(this);
        trackName = el.children('input.track_name')[0].name;
        order     = panel.params.order[trackName];
        
        if (typeof order !== 'undefined' && !lis.filter('.' + trackName).length) {
          tracks.push([ order, el, trackName ]);
          return;
        }
        
        for (i in strand) {
          order = panel.params.order[trackName + '.' + strand[i]];
          
          if (typeof order !== 'undefined' && !lis.filter('.' + trackName + '.' + strand[i]).length) {
            tracks.push([ order, el, trackName + ' ' + strand[i] + (el.hasClass('fav') ? ' fav' : ''), '<div class="strand" title="' + (strand[i] === 'f' ? 'Forward' : 'Reverse') + ' strand"></div>' ]);
          }
        }
        
        el = null;
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
          
          panel.imageConfig[this[2].split(' ')[0]].linked = (panel.imageConfig[this[2].split(' ')[0]].linked || $()).add(li);
          
          li = null;
        });
      } else {
        $.each(tracks, function () {
          panel.imageConfig[this[2].split(' ')[0]].linked = (panel.imageConfig[this[2].split(' ')[0]].linked || $()).add(
            this[1].clone(true).data('order', this[0]).removeClass().addClass(this[2]).children('.controls').prepend(this[3]).end().appendTo(ul).children('.popup_menu').hide().end()
          );
        });
      }
      
      if (tracks.length) {
        panel.updateElLk('track_order');
      }
      
      panel.elLk.trackOrder.show().find('ul.config_menu li').filter(function () { return this.style.display === 'none'; }).show();
      
      ul = lis = null;
    }
    
    function addSection(configDiv) {
      configDiv.html('<div class="spinner">Loading Content</div>');
      
      $.ajax({
        url: url,
        data: { time: new Date().getTime() }, // Cache buster for IE
        dataType: 'json',
        success: function (json) {
          configDiv.html(json.content);
          
          var panelDiv = $('.js_panel', configDiv);
          
          if (panelDiv.length) {
            Ensembl.EventManager.trigger('createPanel', panelDiv[0].id, json.panelType, { links: [ panel.elLk.links.filter('.active').parent().siblings('a').attr('class'), active ] });
            panel.subPanels.push(panelDiv[0].id);
            
            $('input.track_name', panelDiv).each(function () {
              var track  = panel.elLk.tracks.filter('.' + this.name);
              var val    = this.value;
              var newVal = track.children('input.track_name').val();
              
              if (val !== newVal) {
                $(this).siblings('.popup_menu').children('.' + newVal).trigger('click');
                
                // triggering the click above will cause counts to be changed twice, so compensate for that
                if (val === 'off' || newVal === 'off') {
                  panel.elLk.links.children(track.data('links')).siblings('.count').children('.on').html(function (i, html) {
                    return parseInt(html, 10) + (newVal === 'off' ? 1 : -1);
                  });
                }
              }
              
              panel.imageConfig[this.name].linked = (panel.imageConfig[this.name].linked || $()).add(this.parentNode);
              
              track = null;
            });
          } else {
            panel.elLk.viewConfigInputs = $(':input:not([name=select_all])', panel.elLk.viewConfigs);
            panel.setSelectAll();
            
            $(':input:not([name=select_all])', configDiv).each(function () {
              panel.viewConfig[this.name] = this.type === 'checkbox' ? this.checked ? this.value : 'off' : this.value;
            });
          }
        }
      });
    }
    
    function show() {
      if (this.style.display === 'none') {
        this.style.display = 'block';
      }
    }
    
    function findActive() {
      if ((' ' + this.className + ' ').indexOf(' active ') !== -1) {
        return this;
      }
    }
    
    this.el.animate({ scrollTop: 0 }, 0);
    
    if (active.rel === 'multi' ^ this.elLk.form.hasClass('multi')) {
      this.elLk.form[active.rel === 'multi' ? 'addClass' : 'removeClass']('multi')[active.rel !== 'multi' ? 'addClass' : 'removeClass']('single');
    }
    
    this.elLk.configDivs.filter(function () { return this.style.display !== 'none'; }).hide();
    this.elLk.imageConfigExtras.show();
    this.toggleDescription(this.elLk.help, 'hide');
    
    this.lastQuery = false;
    
    if ($(active).attr('href') !== '#') { // $(active).attr('href') if href is set to # in HTML, $(active).attr('href') is '#', but active.href is window.location.href + '#'
      url = active.href;
    }
    
    active = active.className;
    
    if (active.indexOf('-') !== -1) {
      active = active.split('-');
      subset = active[1];
      active = active[0];
    }
    
    this.elLk.headers.hide().filter('.' + active).show();
    
    switch (active) {
      case 'search_results':
        this.elLk.search.val(this.query).css('color', '#000');
        this.search();
        break;
        
      case 'active_tracks':
        this.elLk.configs.hide().filter('.on').show().parents('li, div.subset, div.config').show();
        break;
      
      case 'favourite_tracks':
        favouriteTracks();
        break;
      
      case 'track_order':
        trackOrder();
        break;
        
      default:
        this.addTracks(active);
        
        configDiv = this.elLk.configDivs.filter('.' + active).each(show);
        
        if (subset) {
          configDiv.children('.' + subset).addClass('active').each(show).siblings(':not(.config_header)').map(function () {
            if (this.style.display !== 'none') {
              this.style.display = 'none';
            }
            
            return findActive.call(this);
          }).removeClass('active');
        } else {
          configDiv.children().map(function () {
            show.call(this);
            return findActive.call(this);
          }).removeClass('active');
        }
        
        if (url && !configDiv.children().length) {
          this.addTracks(this.elLk.links.filter('.active').parent().siblings('a').attr('class')); // Add the tracks in the parent panel, for safety
          addSection(configDiv);
        } else {
          configDiv.find('ul.config_menu > li').each(show);
        }
        
        this.elLk.imageConfigExtras.css('display', configDiv.hasClass('view_config') ? 'none' : 'block');
        
        configDiv = null;
    }
  },
  
  formSubmit: function () {
    return false;
  },
  
  updateConfiguration: function (delayReload, saveAs) {
    if ($('input.invalid', this.elLk.form).length) {
      return;
    }
    
    var panel       = this;
    var diff        = false;
    var imageConfig = {};
    var viewConfig  = {};
    
    $.each(this.subPanels, function (i, id) {
      var conf = Ensembl.EventManager.triggerSpecific('updateConfiguration', id, id);
      
      if (conf) {
        $.extend(viewConfig,  conf.viewConfig);
        $.extend(imageConfig, conf.imageConfig);
        diff = true;
      }
    });
    
    this.elLk.tracks.each(function () {
      var fav       = $(this).hasClass('fav');
      var input     = $('input.track_name', this)[0];
      var trackName = input.name;
      var favourite = !panel.imageConfig[trackName].favourite &&  fav ? 1 : // Making a track a favourite
                       panel.imageConfig[trackName].favourite && !fav ? 0 : // Making a track not a favourite
                       false;
      
      if (panel.imageConfig[trackName].renderer !== input.value) {
        imageConfig[trackName] = { renderer: input.value };
        diff = true;
      }
      
      if (favourite !== false) {
        imageConfig[trackName] = imageConfig[trackName] || {};
        imageConfig[trackName].favourite = favourite;
        diff = true;
      }
      
      input = null;
    });
    
    this.elLk.viewConfigInputs.each(function () {
      var value = this.type === 'checkbox' ? this.checked ? this.value : 'off' : this.type === 'select-multiple' ? $('option:selected', this).map(function () { return this.value; }).toArray() : this.value;
      
      if (panel.viewConfig[this.name].toString() !== value.toString()) {
        if (this.name === 'image_width') {
          Ensembl.setWidth(parseInt(value, 10), 1);
          panel.viewConfig.image_width = value;
          Ensembl.EventManager.trigger('changeWidth');
        } else {
          viewConfig[this.name] = value;
          diff = true;
          
          if (this.type === 'select-multiple') {
            panel.viewConfig[this.name] = value; // $.extend(['a','b','c'], ['d','e']) = ['d','e','c']. We want a replacement, not a merge
          }
        }
      }
    });
    
    if (this.trackReorder !== false) {
      imageConfig.track_order = this.trackReorder;
      this.trackReorder = false;
      diff = true;
    }
    
    if (diff === true || typeof saveAs !== 'undefined') {
      $.extend(true, this.imageConfig, imageConfig);
      $.extend(true, this.viewConfig,  viewConfig);
      
      this.updatePage($.extend(saveAs, { image_config: JSON.stringify(imageConfig), view_config: JSON.stringify(viewConfig) }), delayReload);
      
      return diff;
    }
  },
  
  updatePage: function (data, delayReload) {
    var panel = this;
    
    data.submit = 1;
    data.reload = this.params.reset ? 1 : 0;
    
    this.params.reset = false;
    
    $.ajax({
      url:  this.elLk.form.attr('action'),
      type: this.elLk.form.attr('method'),
      data: data, 
      dataType: 'json',
      async: false,
      success: function (json) {
        if (json.existingConfig) {
          panel.updateSavedConfig(json.existingConfig);
        }
        
        if (json.updated) {
          Ensembl.EventManager.trigger('queuePageReload', panel.component, !delayReload);
          
          if (json.imageConfig) {
            $.each(json.trackTypes, function (i, type) { panel.addTracks(type); });
            panel.externalChange(json.imageConfig);
          }
        } else if (json.redirect) {
          Ensembl.redirect(json.redirect);
        }
      }
    });
  },
  
  updateSavedConfig: function (configIds) {
    if (configIds.deleted) {
      this.elLk.existingConfigs.children('.' + configIds.deleted.join(', .')).remove();
    }
    
    if (configIds.saved && !this.elLk.existingConfigs.children('.' + configIds.saved.value).length) {
      $('<option>', configIds.saved).appendTo(this.elLk.existingConfigs);
    }
    
    if (configIds.changed) {
      this.elLk.existingConfigs.children('.' + configIds.changed.id).html(configIds.changed.name);
    }
    
    var existing = this.elLk.existingConfigs.children('[class]').length;
    
    this.elLk.existingConfigs[existing ? 'removeClass' : 'addClass']('disabled').parent()[existing ? 'show' : 'hide']();
  },
  
  activateConfig: function (component) {
    if (!component || component === this.component) {
      Ensembl.EventManager.trigger('modalReload', this.id);
      this.el[this.params.species === Ensembl.species ? 'addClass' : 'removeClass']('active').empty();
    }
  },
  
  saveAsHide: function () {
    this.elLk.modalClose.show();
    this.elLk.saveAs.hide();
    this.elLk.saveAsBg.hide();
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
          Ensembl.EventManager.triggerSpecific('changeTrackOrder', panel.component, track, order);
        }
      }
    });
  },
  
  // Filtering from the search box
  search: function () {
    var panel       = this;
    var noResults   = 'show';
    var els         = { show: [], hide : [], showDesc: [] };
    var searchCache = $.extend([], this.searchCache);
    var added       = [];
    var div, divs, show, menu, ul, tracks, track, i, j, match, type, subset;
    
    function search(n, name, desc, li) {
      match = name.indexOf(panel.query) !== -1;
      
      if (match || desc.indexOf(panel.query) !== -1) {
        if (!panel.imageConfig[n]) {
          li                   = $(li).appendTo(menu);
          subset               = li[0].className.match(/\s*subset_(\w+)\s*/) || false;
          panel.imageConfig[n] = { renderer: 'off', favourite: !!panel.favourites[type] && panel.favourites[type][n], el: li };
          
          added.push(li[0]);
          panel.externalFavourite(n, li);
          
          li.data('links', [
            'a.' + type,
            'a.' + (subset ? subset[1] : type + '-' + menu.parents('.subset').attr('class').replace(/subset|active|first|\s/g, '')) 
          ].join(', '));
        }
        
        if (!match) {
          els.showDesc.push(li[0]);
        }
        
        panel.searchCache.push([ n, name, desc, li, type ]);
        els.show.push(li[0], li.parents('li').toArray());
        
        show      = true;
        noResults = 'hide';
      } else if (panel.imageConfig[n]) {
        els.hide.push(li[0], li.find('div.desc').toArray());
      }
      
      li = null;
    }
    
    this.searchCache = [];
    
    if (this.lastQuery.length >= 2 && this.query.indexOf(this.lastQuery) !== -1) {
      i = searchCache.length;
      
      divs = {};
      
      while (i--) {
        type = searchCache[i][4];
        show = false;
        
        if (typeof divs[type] === 'undefined') {
          divs[type] = false;
        }
        
        search.apply(this, searchCache[i]);
        
        if (show) {
          divs[type] = true;
        }
      }
      
      for (type in divs) {
        if (!divs[type]) {
          els.hide.push(this.elLk.configDivs.filter('.' + type).toArray());
        }
      }
    } else {
      els.hide.push(this.elLk.configDivs.toArray(), this.elLk.configDivs.children('.subset').toArray());
      
      for (type in this.params.tracks) {
        show   = false;
        div    = this.elLk.configDivs.filter('.' + type);
        ul     = div.find('ul.config_menu');
        tracks = this.params.tracks[type];
        i      = tracks.length;
        
        while (i--) {
          menu = ul.eq(i);
          
          for (j in tracks[i]) {
            track = tracks[i][j];
            search(track[0], track[4], track[5], this.imageConfig[track[0]] ? this.imageConfig[track[0]].el : track[1]);
          }
        }
        
        if (show) {
          els.show.push(div[0], div.children('.subset').toArray());
        }
      }
    }
    
    if (added.length) {
      this.updateElLk(added);
    }
    
    this.lastQuery = this.query;
    
    $([].concat.apply([], els.hide)).filter(function () { return this.style.display !== 'none'; }).css('display', 'none');
    $([].concat.apply([], els.show)).filter(function () { return !this.style.display || this.style.display === 'none'; }).css('display', 'block');
    
    this.toggleDescription(els.showDesc, 'show');
    this.elLk.noSearchResults[noResults]();
    
    els = div = menu = ul = null;
  },
  
  toggleDescription: function (els, action) {
    var desc   = $();
    var button = $();
    
    if (typeof els.length === 'undefined') {
      els = [ els ];
    }
    
    var i = els.length;
    
    if (!i) {
      return;
    }
    
    while (i--) {
      switch (els[i].nodeName) {
        case 'LI' : desc.push($(els[i]).children('div.desc')[0]);          button.push($('.menu_help', els[i])[0]); break;
        case 'DIV': desc.push($(els[i]).parent().siblings('div.desc')[0]); button.push(els[i]);                     break;
        default   : break;
      }
    }
    
    switch (action) {
      case 'hide': desc.css('display', 'none');  button.removeClass('open'); break;
      case 'show': desc.css('display', 'block'); button.addClass('open');    break;
      default    : desc.toggle();                button.toggleClass('open');
    }
    
    button.attr('title', function () { return $(this).hasClass('open') ? 'Hide information' : 'Click for more information'; });
    
    this.elLk.help = this.elLk.help.add(button).filter('.open');
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
      
      if (this.imageConfig[trackName]) {
        this.imageConfig[trackName].favourite = selected;
      }
    }
    
    li = div = null;
  },
  
  externalFavourite: function (trackName, el) {
    if (typeof this.externalFavourites[trackName] !== 'undefined') {
      this.imageConfig[trackName].favourite = this.externalFavourites[trackName][0];
      
      if (el.hasClass('fav') !== this.imageConfig[trackName].favourite) {
        el[this.imageConfig[trackName].favourite ? 'addClass' : 'removeClass']('fav');
      }
      
      delete this.externalFavourites[trackName];
    }
  },
  
  // Called when track configuration is changed on the image, rather that in the configuration panel
  externalChange: function (args) {
    var tracks = {};
    
    if (typeof args !== 'object') {
      tracks[arguments[0]] = arguments[1];
    } else {
      tracks = args;
    }
    
    for (var trackName in tracks) {
      this.elLk.tracks.filter('.' + trackName).find('.popup_menu .' + tracks[trackName]).trigger('click');
      this.imageConfig[trackName].renderer = tracks[trackName];
    }
  },
  
  // Called when a view config option is changed, to make sure the identical option is updated in other Configurator panels
  syncViewConfig: function (panelId, filterClass, name, attr, value) {
    var panel = this;
    
    if (this.id !== panelId) {
      var el = this.elLk.viewConfigs.filter('.' + filterClass).find(':input[name=' + name + ']').attr(attr, value);
      
      if (this.viewConfig[name]) {
        this.viewConfig[name] = attr === 'checked' ? value ? el[0].value : 'off' : value;
      }
      
      if (el.attr('name') === 'select_all') {
        el.parents('fieldset').find('input[type=checkbox]').attr('checked', value).each(function () {
          panel.viewConfig[this.name] = value ? this.value : 'off';
        });
      }
      
      el = null;
    }
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
    
    lis = li = null;
  },
  
  destructor: function () {
    this.imageConfig = this.searchCache = null;
    this.base.apply(this, arguments);
  }
});
