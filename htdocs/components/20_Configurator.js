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
      this.elLk.links.removeClass('active').has('.' + this.params.hash).addClass('active');
      delete this.params.hash;
    }
    
    this.elLk.form              = $('form.configuration', this.el);
    this.elLk.headers           = $('h1', this.el);
    this.elLk.search            = $('.configuration_search_text', this.el);
    this.elLk.searchResults     = $('a.search_results', this.elLk.links);
    this.elLk.configDivs        = $('div.config', this.elLk.form);
    this.elLk.configs           = $('ul.config_menu > li', this.elLk.configDivs);
    this.elLk.tracks            = this.elLk.configs.filter('.track');
    this.elLk.help              = $('.menu_help',  this.elLk.configDivs);
    this.elLk.menus             = $('.popup_menu', this.elLk.configDivs);
    this.elLk.favouritesMsg     = this.elLk.configDivs.filter('.favourite_tracks');
    this.elLk.noSearchResults   = this.elLk.configDivs.filter('.no_search');
    this.elLk.trackOrder        = this.elLk.configDivs.filter('.track_order');
    this.elLk.trackOrderList    = $('ul.config_menu', this.elLk.trackOrder);
    this.elLk.viewConfigs       = this.elLk.configDivs.filter('.view_config');
    this.elLk.viewConfigInputs  = $(':input:not([name=select_all])', this.elLk.viewConfigs);
    this.elLk.imageConfigExtras = $('.image_config_notes, .configuration_search', this.el);
    this.elLk.subPanelTracks    = $();
    
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
      
      panel.imageConfig[input.name] = { renderer: input.value, favourite: $(this).hasClass('fav') };
      
      input = null;
    });
    
    this.elLk.viewConfigInputs.each(function () {
      panel.viewConfig[this.name] = this.type === 'checkbox' ? this.checked ? this.value : 'off' : this.value;
    });
    
    $(':input', this.elLk.viewConfigs).bind('change', function () {
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
    
    if (this.sortable) {
      this.makeSortable();
    }
    
    this.live.push(
      $('.menu_help', this.elLk.configDivs).live('click', function () { panel.toggleDescription(this); }),
      
      $('.favourite', this.elLk.configDivs).live('click', function () {
        Ensembl.EventManager.trigger(
          'changeFavourite', 
          $(this).parent().siblings('input.track_name')[0].name,
          $(this).parents('li.track').hasClass('fav') ? 0 : 1,
          $(this).parents('div.config')[0].className.replace(/config /, ''),
          panel.id
        );
      }),
      
      $('ul.config_menu > li.track', this.elLk.configDivs).live('click', function (e) {
        if (e.target === this) {
          $(this).children('img.menu_option').trigger('click');
        }
      }),
      
      // Popup menus - displaying
      $('.menu_option', this.elLk.configDivs).live('click', function () {
        var menu     = $(this).siblings('.popup_menu');
        var current  = menu.find('span.current');
        var selected = $(this).siblings('input.track_name').val();
        
        if (menu.children().length === 2 && !$(this).parent().hasClass('select_all')) {
          menu.children(':not(.' + selected + ')').trigger('click');
        } else {
          panel.elLk.menus.filter(':visible').not(menu).hide();
          menu.toggle();
        }
        
        if (current.parent().attr('class') !== selected) {
          menu.find('span.current').removeClass('current').siblings('img.tick').detach().insertBefore(menu.find('.' + selected + ' span').addClass('current'));
        }
        
        menu = current = null;
      }),
      
      // Popup menus - setting values
      $('.popup_menu li:not(.header)', this.elLk.configDivs).live('click', function () {
        var li      = $(this);
        var img     = li.children('img');
        var menu    = li.parents('.popup_menu');
        var track   = menu.parent();
        var val     = li.attr('class');
        var change  = 0;
        var updated = {};
        
        if (track.hasClass('select_all')) {
          track = track.next().find('li.track:not(.hidden, .external)');
          
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
        
        if (panel.sortable) {
          $.each(updated, function (trackName, attrs) {
            $.each([panel.elLk.tracks, panel.elLk.trackOrderList.children(), panel.elLk.subPanelTracks], function () {
              $(this).filter('.' + trackName).not(li).children('img.menu_option').attr({ 
                src:   '/i/render/' + attrs[0] + '.gif', 
                alt:   attrs[1],
                title: attrs[1]
              }).siblings('input.track_name').val(attrs[0]).parent()[attrs[0] === 'off' ? 'removeClass' : 'addClass']('on');
            });
          });
        }
        
        menu = track = img = li = null;
      }),
      
      $('.popup_menu li.header', this.elLk.configDivs).live('click', function (e) {
        if (e.target.className === 'close') {
          $(this).parent().hide();
        }
        
        return false;
      })
    );
    
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
            panel.elLk.headers.hide().filter('.search_results').show();
            panel.elLk.imageConfigExtras.show();
            panel.elLk.form.addClass('multi').removeClass('single');
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
      var link = $(this).parent().attr('class').replace(/\s*config\s*/, '');
      $('a.' + link, panel.elLk.links).trigger('click');
    });
    
    $('select.species', this.el).bind('change', function () {
      if (this.value) {
        var species = this.value.split('/')[1];
        var id      = 'modal_config_' + (panel.component + (species === Ensembl.species ? '' : '_' + species)).toLowerCase();
        var change  = $('#' + id);
        
        panel.hide();
        
        if (!change.length) {
          Ensembl.EventManager.trigger('updateConfiguration', true);
          change = $('<div>', { id: id, 'class': 'modal_content js_panel active', html: '<div class="spinner">Loading Content</div>' });
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
    
    
    this.elLk.links.has('.user_data').insertAfter(this.elLk.links.has('[rel=multi]').last()); // Move user data to below the multi entries (active tracks, favourites, search)
    
    this.getContent();
  },
  
  addTracks: function (type) {
    if (this.populated[type] || !this.params.tracks[type]) {
      return;
    }
    
    var panel    = this;
    var tracks   = this.params.tracks[type];
    var configs  = this.elLk.configDivs.filter('.' + type).find('ul.config_menu');
    var existing = [];
    var i        = tracks.length;
    var j, track, li, link;
    
    function setConfig(trackName) {
      if (!panel.imageConfig[trackName]) {
        panel.imageConfig[trackName] = { renderer: 'off', favourite: !!panel.favourites[type] && panel.favourites[type][trackName] };
      }
      
      panel.externalFavourite(trackName, li);
    }
    
    configs.each(function (k) {
      if (!existing[k]) {
        existing[k] = {};
      }
      
      $(this).children('.track').each(function () {
        $('input.track_name', this).each(function () {
          existing[k][this.name] = $(this).parent('li');
        });
      }).detach();
    });
    
    while (i--) {
      j    = tracks[i].length;
      link = $(configs[i]).parents('.subset').attr('class').replace(/subset|active|first|\s/g, '');
      
      while (j--) {
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
        
        $(configs[i]).prepend(li);
      }
      
      $(configs[i]).find('.track').each(function () {
        var subset = this.className.match(/\s*subset_(\w+)\s*/) || false;

        $(this).data('links', [
          'a.' + type,
          'a.' + (subset ? subset[1] : type + '-' + link) 
        ].join(', '));
      });
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
            li = $(panel.favourites[type][trackName][1]).appendTo(panel.elLk.configDivs.filter('.' + type).find('ul.config_menu').eq(panel.favourites[type][trackName][0]));
            li.data('links', [
              'a.' + type,
              'a.' + (subset ? subset[1] : type + '-' + li.parents('.subset').attr('class').replace(/subset|active|first|\s/g, '')) 
            ].join(', '));
            
            panel.imageConfig[trackName] = { renderer: 'off', favourite: 1 };
            added = true;
          }
          
          li = null;
        }
      }
      
      if (added) {
        panel.updateElLk();
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
      
      ul = lis = null;
    }
    
    function addSection() {
      configDiv = $('<div>', {
        'class': 'config view_config ' + active,
        html:    '<div class="spinner">Loading Content</div>'
      }).appendTo(panel.elLk.form);
      
      panel.elLk.configDivs  = $('div.config', panel.elLk.form);
      panel.elLk.viewConfigs = panel.elLk.configDivs.filter('.view_config');
      
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
            
            panel.elLk.subPanelTracks = panel.elLk.subPanelTracks.add($('input.track_name', panelDiv).each(function () {
              var track = panel.elLk.tracks.filter('.' + this.name);
              var val   = track.children('input.track_name').val();
              
              if (this.value !== val) {
                $(this).siblings('.popup_menu').children('.' + val).trigger('click');
                
                // triggering the click above will cause counts to be changed twice, so compensate for that
                if (val === 'off' || this.value === 'off') {
                  panel.elLk.links.children(track.data('links')).siblings('.count').children('.on').html(function (i, html) {
                    return parseInt(html, 10) + (val === 'off' ? 1 : -1);
                  });
                }
              }
              
              track = null;
            }).parent());
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
    
    this.el.animate({ scrollTop: 0 }, 0);
    
    if (active.rel === 'multi' ^ this.elLk.form.hasClass('multi')) {
      this.elLk.form[active.rel === 'multi' ? 'addClass' : 'removeClass']('multi')[active.rel !== 'multi' ? 'addClass' : 'removeClass']('single');
    }
    
    this.elLk.configDivs.filter(function () { return this.style.display !== 'none'; }).hide();
    this.elLk.help.filter('.open').removeClass('open').attr('title', 'Click for more information').parent().siblings('div.desc').hide();
    this.elLk.imageConfigExtras.show();
    
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
        this.elLk.search.val(this.query);
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
        configDiv = this.elLk.configDivs.filter('.' + active).show();
        
        if (subset) {
          subset = configDiv.children('.' + subset).addClass('active').show();
          configDiv.children(':not(.config_header)').not(subset).removeClass('active').hide();
          subset = null;
        } else {
          configDiv.children().removeClass('active').show();
        }
        
        if (url && !configDiv.length) {
          this.addTracks(this.elLk.links.filter('.active').parent().siblings('a').attr('class')); // Add the tracks in the parent panel, for safety
          addSection();
        } else {
          configDiv.find('ul.config_menu li').filter(function () { return this.style.display === 'none'; }).show();
        }
        
        this.elLk.imageConfigExtras[configDiv.hasClass('view_config') ? 'hide' : 'show']();
    }
    
    if (this.elLk.links.filter('.active').is('.overflow') && !$('body').hasClass('ie67')) {
      this.elLk.content.addClass('overflow').css('marginLeft', $('.modal_nav', this.el).outerWidth() + 2);
    } else {
      this.elLk.content.removeClass('overflow').css('marginLeft', 0);
    }
  },
  
  updateConfiguration: function (delayReload) {
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
      var value = this.type === 'checkbox' ? this.checked ? this.value : 'off' : this.value;
      
      if (panel.viewConfig[this.name] !== value) {
        if (this.name === 'image_width') {
          Ensembl.setWidth(parseInt(value, 10), 1);
          panel.viewConfig.image_width = value;
          Ensembl.EventManager.trigger('changeWidth');
        } else {
          viewConfig[this.name] = value;
          diff = true;
        }
      }
    });
    
    if (this.trackReorder !== false) {
      imageConfig.track_order = this.trackReorder;
      this.trackReorder = false;
      diff = true;
    }
    
    if (diff === true) {
      $.extend(true, this.imageConfig, imageConfig);
      $.extend(true, this.viewConfig,  viewConfig);
      
      this.updatePage({ image_config: JSON.stringify(imageConfig), view_config: JSON.stringify(viewConfig) }, delayReload);
      
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
    var panel     = this;
    var lis       = [];
    var added     = false;
    var noResults = 'show';
    var div, show, menu, tracks, track, trackName, i, j, match, type, subset;
    
    function search(n, li) {
      match = li.children('span.menu_option').text().match(panel.regex);
      
      if (match || li.children('div.desc').text().match(panel.regex)) {
        if (panel.imageConfig[n]) {
          li.show().parents('li').show();
        } else {
          menu.append(li.show()).parents('li').show();
          panel.imageConfig[n] = { renderer: 'off', favourite: !!panel.favourites[type] && panel.favourites[type][n] };
          panel.externalFavourite(n, li);
          added  = true;
          subset = li[0].className.match(/\s*subset_(\w+)\s*/) || false;
       
          li.data('links', [
            'a.' + type,
            'a.' + (subset ? subset[1] : type + '-' + menu.parents('.subset').attr('class').replace(/subset|active|first|\s/g, '')) 
          ].join(', '));
        }
        
        show      = true;
        noResults = 'hide';
        
        if (!match) {
          lis.push(li[0]);
        }
      } else if (panel.imageConfig[trackName]) {
        li.hide().find('div.desc').hide();
      }
    }
    
    this.elLk.configDivs.hide().children('.subset').hide();
    
    for (type in this.params.tracks) {
      div    = this.elLk.configDivs.filter('.' + type);
      show   = false;
      tracks = this.params.tracks[type];
      i      = tracks.length;
      
      while (i--) {
        menu = div.find('ul.config_menu').eq(i);
        
        for (j in tracks[i]) {
          track     = tracks[i][j];
          trackName = track[0];
          
          search(trackName, this.imageConfig[trackName] ? menu.find('li.' + trackName) : $(track[1]));
        }
        
        menu = null;
      }
      
      if (show) {
        div.show().children('.subset').show();
      }
      
      div = null;
    }
    
    if (added) {
      this.updateElLk();
    }
    
    this.lastQuery = this.query;
    this.toggleDescription(lis, 'show');
    this.elLk.noSearchResults[noResults]();
    
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
      
      desc = button = null;
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
  }
});
