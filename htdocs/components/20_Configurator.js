/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2018] EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

Ensembl.Panel.Configurator = Ensembl.Panel.ModalContent.extend({
  constructor: function (id, params) {
    if (params.trackIds) {
      var i      = params.trackIds.length;
      var tracks = {};
      
      while (i--) {
        tracks[params.trackIds[i]] = params.tracks[i]; // convert tracks from an array into a hash
      }
      
      this.tracks = tracks;
      
      delete params.tracks;
      delete params.trackIds;
    } else {
      params.tracksByType = {}; // Make sure ViewConfigs don't break
    }
    
    this.base(id, params);
    
    Ensembl.EventManager.register('updateConfiguration', this, this.updateConfiguration);
    Ensembl.EventManager.register('showConfiguration',   this, this.show);
    Ensembl.EventManager.register('changeConfiguration', this, this.externalChange);
    Ensembl.EventManager.register('changeTrackOrder',    this, this.externalOrder);
    Ensembl.EventManager.register('changeFavourite',     this, this.changeFavourite);
    Ensembl.EventManager.register('syncViewConfig',      this, this.syncViewConfig);
    Ensembl.EventManager.register('updateSavedConfig',   this, this.updateSavedConfig);
    Ensembl.EventManager.register('activateConfig',      this, this.activateConfig);
    Ensembl.EventManager.register('resetConfig',         this, this.externalReset);
    Ensembl.EventManager.register('refreshConfigList',   this, this.refreshConfigList);
    Ensembl.EventManager.register('changeMatrixTrackRenderers', this, this.changeMatrixTrackRenderers);
  },
  
  init: function () {
    var panel = this;
    var track, type, group, i, j;
    
    this.base();

    // move search to lhs
    this.el.find('.configuration_search').prependTo(this.el.closest('.modal_content').find('.modal_nav').first());


    this.elLk.form              = $('form.configuration', this.el);
    this.elLk.headers           = $('h1', this.el);
    this.elLk.search            = $('.configuration_search_text', this.el);
    this.elLk.searchResults     = $('a.search_results', this.elLk.links);
    this.elLk.configDivs        = $('div.config', this.elLk.form);
    this.elLk.configMenus       = this.elLk.configDivs.find('ul.config_menu');
    this.elLk.configs           = this.elLk.configMenus.children('li');
    this.elLk.tracks            = this.elLk.configs.filter('.track');
    this.elLk.favouritesMsg     = this.elLk.configDivs.filter('.favourite_tracks');
    this.elLk.noSearchResults   = this.elLk.configDivs.filter('.no_search');
    this.elLk.trackOrder        = this.elLk.configDivs.filter('.track_order');
    this.elLk.trackOrderList    = $('ul.config_menu', this.elLk.trackOrder);
    this.elLk.viewConfigs       = this.elLk.configDivs.filter('.view_config');
    this.elLk.viewConfigInputs  = $(':input:not([name=select_all])', this.elLk.viewConfigs);
    this.elLk.imageConfigExtras = $('.image_config_notes, .configuration_search', this.el);
    this.elLk.saveAs            = $('.config_save_as', this.el).detach(); // will be put into the modal overlay
    this.elLk.saveAsInputs      = $('.name, .desc, .default, .existing, input.group', this.elLk.saveAs);
    this.elLk.saveAsRequired    = this.elLk.saveAsInputs.filter('.name, .existing');
    this.elLk.existingConfigs   = this.elLk.saveAsInputs.filter('.existing');
    this.elLk.saveTo            = $('.save_to', this.elLk.saveAs);
    this.elLk.saveAsGroup       = $('.groups',  this.elLk.saveAs);
    this.elLk.saveAsSubmit      = $('.fbutton', this.elLk.saveAs);
    this.elLk.popup             = $();
    this.elLk.help              = $();

    // new config sets stuff
    this.elLk.configForm        = this.el.find('._config_settings');
    this.elLk.configDropdown    = this.elLk.configForm.find('._config_dropdown');
    this.elLk.configSelector    = this.elLk.configDropdown.find('select');
    this.elLk.configSaveAsLink  = $('<a href="#" class="small left-margin"></a>').insertAfter(this.elLk.configSelector).hide().on('click', {panel: this}, function(e) { e.preventDefault(); e.data.panel.configSave(true); });
    this.elLk.configSaveLink    = $('<a href="#" class="small left-margin"></a>').insertAfter(this.elLk.configSelector).hide().on('click', {panel: this}, function(e) { e.preventDefault(); e.data.panel.configSave(); });
    this.elLk.configSaveInput   = this.elLk.configDropdown.find('div:has(input)').hide();

    this.component          = $('input.component', this.elLk.form).val();
    this.sortable           = !!this.elLk.trackOrder.length;
    this.lastQuery          = false;
    this.populated          = {};
    this.favourites         = {};
    this.externalFavourites = {};
    this.imageConfig        = {};
    this.viewConfig         = {};
    this.subPanels          = [];
    this.searchCache        = [];

    for (type in this.params.tracksByType) {
      group = this.params.tracksByType[type];
      i     = group.length;
      
      while (i--) {
        for (j in group[i]) {
          track = this.tracks[group[i][j]];
          
          if (track.fav) {
            if (!this.favourites[type]) {
              this.favourites[type] = {};
            }
            
            this.favourites[type][group[i][j]] = [ i, track.html ];
          }
        }
      }
    }

    this.elLk.tracks.each(function () {
      var track = panel.tracks[this.id];
      track.el = $(this).data('track', track).removeAttr('id');
      panel.imageConfig[track.id] = { renderer: track.renderer, favourite: track.fav };
    });
    
    this.elLk.viewConfigInputs.each(function () {
      panel.viewConfig[this.name] = this.type === 'checkbox' ? this.checked ? this.value : 'off' : this.type === 'select-multiple' ? $('option:selected', this).map(function () { return this.value; }).toArray() : this.value;
    });
    
    if (this.sortable) {
      this.makeSortable();
    }
    
    this.elLk.configDivs.not('.view_config')
    .on('click', 'ul.config_menu > li.track div.track_name, .select_all', $.proxy(this.showConfigMenu, this)) // Popup menus - displaying
    .on('click', '.popup_menu li',                         $.proxy(this.setTrackConfig, this)) // Popup menus - setting values
    .on('click', '.config_header', function () {                                               // Header on search results and active tracks sections will act like the links on the left
      $('a.' + this.parentNode.className.replace(/\s*config\s*/, ''), panel.elLk.links).trigger('click');
      return false;
    }).on('click', '.matrix_link', function () {
      $('a.regulatory_features', panel.elLk.links).trigger('click');
      return false;
    }).on('click', '.favourite', function () {
      var track = $(this).parents('li.track').data('track');
      Ensembl.EventManager.trigger('changeFavourite', track.id, track.fav ? 0 : 1, track.type, panel.id);
      return false;
    }).on('click', '.menu_help', function () {
      panel.toggleDescription(this);
      return false;
    });
    
    this.elLk.viewConfigs.on('change', ':input', function () {
      var value, prop;
      
      if (this.type === 'checkbox') {
        value = this.checked;
        prop  = 'checked';
      } else {
        value = this.value;
        prop  = 'value';
      }
      
      Ensembl.EventManager.trigger('syncViewConfig', panel.id, $(this).parents('.config')[0].className.replace(/ /g, '.'), this.name, prop, value);
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
    
    this.el.find('select[name=species]').on('change', function () {
      var species = this.value.replace(/^\//, '').split(/\//).shift();
      var id      = 'modal_config_' + (panel.component + (species === Ensembl.species ? '' : '_' + species)).toLowerCase();
      var change  = $('#' + id);

      panel.hide();
      if (!change.length || !change.children().length || change.data('reload')) {
        Ensembl.EventManager.trigger('updateConfiguration', true);
        change = change.length ? !change.removeData('reload') : $('<div>', { id: id, 'class': 'modal_content js_panel active', html: '<div class="spinner">Loading Content</div>' });
        Ensembl.EventManager.trigger('addModalContent', change, this.value, id, 'modal_config_' + panel.component.toLowerCase());
      } else {
        change.addClass('active').show().find('select[name=species]').prop('selectedIndex', this.selectedIndex).selectToToggle('trigger').focus();
      }

      $(panel.el).removeClass('active');
      Ensembl.EventManager.trigger('setActivePanel', id);
      panel.updateConfiguration(true);

      change = null;
    });
    
    $('.save_configuration', this.el).on('click', function (e) { // TODO - remove

      e.preventDefault();
      return;

      /*
      panel.elLk.saveAsInputs.each(function () {
        var el = $(this);
        
        if (el.hasClass('default')) {
          el.prop('checked', true);
        } else if (this.type === 'checkbox') {
          el.prop('checked', false);
        } else {
          el.val('');
        }
        
        el = null;
      });
      
      panel.el.scrollTop(0);
      panel.elLk.saveAsSubmit.prop('disabled', true).addClass('disabled');
      panel.elLk.saveAsGroup.hide();
      
      Ensembl.EventManager.trigger('modalOverlayShow', panel.elLk.saveAs);
      
      return false;
      */
    });
    
    function saveAsState() {
      var disabled = !$.grep(panel.elLk.saveAsRequired.not('.disabled'), function (el) { return el.value; }).length;
      panel.elLk.saveAsSubmit.prop('disabled', disabled)[disabled ? 'addClass' : 'removeClass']('disabled');
    }
    
    this.elLk.saveAsInputs.filter('.name').on('keyup blur input', saveAsState);
    this.elLk.existingConfigs.on('change', saveAsState);
    
    this.elLk.saveTo.on('click', function () {
      panel.elLk.saveAsGroup[this.value === 'group' ? 'show' : 'hide']();
    });
    
    this.elLk.saveAsSubmit.on('click', function () {
      var saveAs = { save_as: 1 };
      
      $.each($(this).parents('form').serializeArray(), function () {
        var val = this.value.replace(/<[^>]+>/g, '');
        
        if (saveAs[this.name]) {
          saveAs[this.name] = $.isArray(saveAs[this.name]) ? saveAs[this.name] : [ saveAs[this.name] ];
          saveAs[this.name].push(val);
        } else {
          saveAs[this.name] = val;
        }
      });
      
      if (saveAs.name || saveAs.overwrite) {
        panel.updateConfiguration(true, saveAs);
        Ensembl.EventManager.trigger('modalOverlayHide');
      }
    });
    
    this.getContent();
    this.el.externalLinks();
    this.initConfigList();
  },

  initFromHash: function() {
    if (this.params.hash) {
      var newActive = this.elLk.links.children('.' + this.params.hash);
      if(newActive.length) {
        this.elLk.links.removeClass('active');
        newActive.parent().addClass('active');
      }
      delete this.params.hash;
    }
  },

  showConfigMenu: function (e) {
    if (e.target.nodeName === 'A') {
      return true;
    }
    
    var el        = $(e.currentTarget);
    var selectAll = el.hasClass('select_all');

    if (el.hasClass('track_name')) {
      el = el.parent();
    }

    if (selectAll && e.target === e.currentTarget) {
      return false; // Stop clicks for select all firing unless you click on the actual text, not the div
    }
    
    var data = el.data();
    
    if (!data.popup || data.popup.parentNode !== el[0]) {
      var existing = el.children('.popup_menu');
      
      data.popup = existing.length ? existing : $(data.track.popup).prependTo(el);
      
      if (selectAll) {
        existing.children('.current').removeClass('current');
      }
      
      existing = null;
    }
    
    if (data.popup.children().length === 2 && !selectAll) {
      data.popup.children(':not(.' + data.track.renderer + ')').trigger('click');
    } else {
      this.elLk.popup.not(data.popup.show()).hide();
      this.elLk.popup = data.popup;
    }
    
    if (!selectAll) {
      var renderer = data.popup.children('.' + data.track.renderer);
      
      if (!renderer.hasClass('.current')) {
        renderer.addClass('current').siblings('.current').removeClass('current');
      }
      
      renderer = null;
    }
    
    el = null;
    
    return false;
  },
  
  setTrackConfig: function (e, updateCount) {
    var target = $(e.target);
    
    if (target.is('.header') || target.filter('.close').parents('.popup_menu').hide().length) {
      target = null;
      return false;
    }
    
    var renderer = e.target.className;
    var popup    = target.parents('ul.popup_menu').hide();
    var track    = popup.parent();
    var current  = renderer.match(/\s*current\s*/);
    var subset   = e.currentTarget.className.match(/\s*subset_(\w+)\s*/); // use currentTarget since target can be either the li or the a inside it
    
    if (current || subset) {
      if (subset) {
        this.elLk.links.children('a.' + subset[1]).trigger('click'); // li has a link which opens a subset - helps users find matrix config for tracks
      }
    } else {
      this.changeTrackRenderer(track.hasClass('select_all') ? track.next().find('li.track:not(.hidden)') : track, renderer, updateCount);
    }
    
    popup = track = target = null;
    
    return false;
  },

  // e.g. data = {"seg_Segmentation_astrocyte":{"renderer":"off"},"reg_feats_astrocyte":{"renderer":"normal"}
  changeMatrixTrackRenderers: function(trackData) {
    var panel = this;
    var trackData;
    $.each(trackData, function(key, val) {
      if (panel.tracks[key]) {
        trackData = $(panel.tracks[key].el).data();
        trackData.track.renderer = val.renderer || 'off' ;
      }
    })
  },
  
  changeTrackRenderer: function (tracks, renderer, updateCount, isConfigMatrix) {
    var subTracks = this.params.subTracks || {};
    var change    = 0;
    var subTrack, c;
    
    if (renderer === 'all_on') {
      tracks.each(function () {
        var data = $(this).data();
        data.track.newRenderer = (data.popup = data.popup || $(data.track.popup).prependTo(this)).children('li.off +')[0].className; // Use the first renderer after "off" as default on setting.
      });
    }
    
    tracks.each(function () {
      var track = $(this).data('track');
      var els   = track.el.add(track.linkedEls);
      
      els.removeClass(track.renderer + ' on');
      
      if (track.renderer === 'off' ^ renderer === 'off') {
        c = renderer === 'off' ? -1 : 1;
        
        if (typeof subTracks[track.id] === 'number') {
          change  += c * subTracks[track.id];
          subTrack = true;
        } else {
          change += c;
          
          if (updateCount !== false) {
            updateCount = true;
          }
        }
      }
      
      els.each(function () {
        $(this).data('track').renderer = track.newRenderer || renderer;
      }).addClass(track.renderer + (track.renderer === 'off' ? '' : ' on')); // track.renderer is changed during the each, above
      
      delete track.newRenderer;
      
      els = null;
    });
    
    if (subTrack && updateCount !== false) {
      if (Ensembl.EventManager.trigger('changeColumnRenderer', $.map(tracks, function (i) { return $(i).data('track').id; }), renderer, true)) {
        updateCount = false;
      }
    }
    
    if (updateCount !== false) {
      this.elLk.links.children(tracks.data('track').links).siblings('.count').children('.on').html(function (i, html) {
        return parseInt(html, 10) + change;
      });
    }
    
    tracks = null;

    this.configSettingChanged(isConfigMatrix);
  },
  
  addTracks: function (type) {
    if (this.populated[type] || !this.params.tracksByType[type]) {
      return;
    }
    
    var tracksByType = this.params.tracksByType[type];
    var tracks       = this.tracks;
    var configs      = this.elLk.configDivs.filter('.' + type).find('ul.config_menu').each(function (i) { $.data(this, 'index', i); });
    var hasPopup     = this.elLk.popup.length ? this.elLk.popup.parent().data('track') : false;
    var configMenus  = $();
    var data         = { imageConfigs: [], html: [], submenu: [] };
    var i            = tracksByType.length;
    var j, track, li, ul, lis, link;
    
    while (i--) {
      j  = tracksByType[i].length;
      ul = configs.eq(i);
      
      data.html[i]         = [];
      data.imageConfigs[i] = [];
      data.submenu[i]      = false;
      
      while (j--) {
        track = tracks[tracksByType[i][j]];
        
        if (tracks[track.id].el) {
          tracks[track.id].el.remove();
          data.html[i].unshift([ '<li class="', tracks[track.id].el[0].className , '" id="', track.id, '">', tracks[track.id].el[0].innerHTML, '</li>' ].join(''));
        } else {
          data.html[i].unshift(track.html);
        }
        
        data.imageConfigs[i][j] = track.id;
      }
      
      if (ul[0].innerHTML) {
        ul.children(':has(.config_menu)').each(function () {
          data.html[i].push('<li class="', this.className, '" id="', this.id, '">');
          
          $.each($(this).children('.config_menu'), function () {
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
    
    i = tracksByType.length;
    
    while (i--) {
      if (data.html[i]) {
        configs[i].innerHTML = data.html[i];
      }
    }
    
    // must loop forwards here, since parent uls will write the content of child uls 
    for (i = 0; i < tracksByType.length; i++) {
      ul   = configs.eq(i);
      j    = data.imageConfigs[i].length;
      link = ul.parents('.subset').attr('class').replace(/subset|active|first|\s/g, '');
      lis  = ul.children();
      
      if (data.submenu[i]) {
        lis.children('ul.config_menu').each(function (k) { configs[i + k + 1] = this; }); // alter the configs entry for all child uls after adding the content
      }
      
      lis.filter('.track').each(function () { $.data(this, 'track', tracks[this.id]); }).removeAttr('id');
      
      while (j--) {
        li    = lis.eq(j);
        track = data.imageConfigs[i][j];
        
        tracks[track].el = li;
        
        if (!this.imageConfig[track]) {
          this.imageConfig[track] = { renderer: 'off', favourite: !!this.favourites[type] && this.favourites[type][track] };
        }
        
        this.externalFavourite(track, li);
      }
    }
    
    if (hasPopup) {
      this.elLk.popup = tracks[hasPopup.id].el.children('.popup_menu');
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
    this.elLk.popup.hide();
    
    if (active) {
      this.elLk.links.removeClass('active').find('.' + active).parent().addClass('active');
    }
    
    this.base();
    this.getContent();
  },
  
  getContent: function (linkEle, href) {
    var panel  = this;
    var active = this.elLk.links.filter('.active').children('a')[0];
    var url, configDiv, subset;
    function favouriteTracks() {
      var trackId, li, type;
      var external = $.extend({}, panel.externalFavourites);
      var added    = [];
      
      for (trackId in external) {
        if (external[trackId]) {
          panel.addTracks(external[trackId][1]);
        } else {
          delete panel.favourites[external[trackId][1]][trackId];
        }
      }
      
      for (type in panel.favourites) {
        for (trackId in panel.favourites[type]) {
          if (!panel.imageConfig[trackId]) {
            li = $(panel.favourites[type][trackId][1]).appendTo(panel.elLk.configDivs.filter('.' + type).find('ul.config_menu').eq(panel.favourites[type][trackId][0]));
            
            panel.tracks[trackId].el = li.data('track', panel.tracks[trackId]);
            panel.imageConfig[trackId] = { renderer: 'off', favourite: 1 };
            added.push(li[0]);
            
            li = null;
          }
        }
      }
      
      if (added.length) {
        panel.updateElLk(added);
      }
      
      panel.elLk.favouritesMsg[panel.elLk.configs.hide().filter('.track.fav').show().parents('li, div.subset, div.config').show().length ? 'hide' : 'show']();
    }
    
    function trackOrder() {
      var ul     = panel.elLk.trackOrderList;
      var lis    = ul.children();
      var strand = [ 'f', 'r' ];
      var tracks = [];
      var i, track, trackId, fav, order, li;
      
      panel.elLk.tracks.filter('.on').each(function () {
        var el    = $(this);
            track = el.data('track');
            fav   = track.fav ? ' fav' : '';
            order = panel.params.order[track.id];
        
        if (typeof order !== 'undefined' && !lis.filter('.' + track.id).length) {
          tracks.push([ order, el, track.id ]);
          return;
        }
        
        for (i in strand) {
          order = panel.params.order[track.id + '.' + strand[i]];
          
          if (typeof order !== 'undefined' && !lis.filter('.' + track.id + '.' + strand[i]).length) {
            tracks.push([ order, el, track.id + ' ' + strand[i] + fav, '<div class="strand" title="' + (strand[i] === 'f' ? 'Forward' : 'Reverse') + ' strand"></div>' ]);
          }
        }
        
        el = null;
      });
      
      tracks = tracks.sort(function (a, b) { return a[0] - b[0]; });
      
      if (lis.length) {
        $.each(tracks, function () {
          trackId = this[2].split(' ')[0];
          i       = lis.length;
          li      = this[1].clone(true).data({
            order:     this[0],
            trackName: this[2],
            trackId:   trackId
          }).removeAttr('id').removeClass('track').addClass(this[2]).children('.controls').prepend(this[3]).end();
          
          while (i--) {
            if ($(lis[i]).data('order') < this[0]) {
              li.insertAfter(lis[i]);
              break;
            }
          }
          
          if (i === -1) {
            li.insertBefore(lis[0]);
          }
          
          panel.tracks[trackId].linkedEls = (panel.tracks[trackId].linkedEls || $()).add(li);
          
          li = null;
        });
      } else {
        $.each(tracks, function () {
          trackId = this[2].split(' ')[0];
          
          panel.tracks[trackId].linkedEls = (panel.tracks[trackId].linkedEls || $()).add(
            this[1].clone(true).data({
              order:     this[0],
              trackName: this[2],
              trackId:   trackId
            }).removeAttr('id').addClass(this[2]).children('.controls').prepend(this[3]).end().appendTo(ul).children('.popup_menu').hide().end()
          );
        });
      }
      
      if (tracks.length) {
        panel.updateElLk('track_order');
      }
      
      panel.elLk.trackOrder.show().find('ul.config_menu li').filter(function () { return this.style.display === 'none'; }).show();
      
      ul = lis = null;
    }
    
    function addSection(configDiv, linkEle) {
      configDiv.html('<div class="spinner">Loading Content</div>');
      $.ajax({
        url: url,
        cache: false, // Cache buster for IE
        dataType: 'json',
        success: function (json) {
          var width = configDiv.width(); // Calculate width of div before adding content - much faster to do it now
          configDiv.detach().html(json.content).insertAfter(panel.elLk.form); // fix for Chrome being slow when inserting a large content into an already large form.
          
          var panelDiv = $('.js_panel', configDiv);
          
          if (panelDiv.length) {
            Ensembl.EventManager.trigger('createPanel', panelDiv[0].id, json.panelType, $.extend(json.params, {
              links:        panel.elLk.links.filter('.active').parents('li.parent').andSelf(),
              parentTracks: panel.tracks,
              width:        width,
              clickedLink:  linkEle
            }));
            
            panel.subPanels.push(panelDiv[0].id);
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
    // Hide all captions and show only the funcgen captions on Active tracks below
    this.elLk.configDivs.filter('.functional').find('.hidden-caption').hide();

    switch (active) {
      case 'search_results':
        this.elLk.search.val(this.query).css('color', '#000');
        this.search();
        break;
        
      case 'active_tracks':
        this.elLk.configs.hide().filter('.on').show().parents('li, div.subset, div.config').show();
        this.elLk.configDivs.filter('.functional').find('.hidden-caption').show();
  
        // Hide trackhub tracks
        this.elLk.configDivs.filter('.matrix').hide();

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
       
        if (configDiv.hasClass('has_matrix') && !subset) {
          // Hide subsections on trackhub parent page
          configDiv.children('.multiple').each(function () { this.style.display = 'none' });
        } 
        else if (subset) {
          configDiv.children('.' + subset).addClass('active').each(show).siblings(':not(.config_header)').map(function () {
            if (this.style.display !== 'none') {
              this.style.display = 'none';
            }
            
            return findActive.call(this);
          }).removeClass('active');
        } else {
          if (configDiv.hasClass('functional') && !subset) {
            // Hide tracks that are configured using matrix
            configDiv.children('.subset').each( function() {
              if (this.className.match(/regulatory_features/)) {
                var ul = this.childNodes[1];
                ul.hidden = true;
              }
            });
          }
          configDiv.children().map(function () {
            show.call(this);
            return findActive.call(this);
          }).removeClass('active');
        }
        
        if (url) {
          if (!configDiv.children().length) {
            this.addTracks(this.elLk.links.filter('.active').parent().siblings('a').attr('class')); // Add the tracks in the parent panel, for safety
            addSection(configDiv, linkEle);
          }
          
          configDiv.data('active', true);
          this.elLk.configDivs.not(configDiv).data('active', false);
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
    var menu_ids    = [];
    var matrix = 0;
    $.each(this.subPanels, function (i, id) {
      var conf = Ensembl.EventManager.triggerSpecific('updateConfiguration', id, id, true);

      if (conf) {
        $.extend(viewConfig,  conf.viewConfig);
        $.extend(imageConfig, conf.imageConfig);
        if (conf.menu_id) {
          menu_ids.push(conf.menu_id);
        }
        diff = true;
        matrix = conf.matrix;
      }
    });

    this.elLk.tracks.each(function () {
      var track   = $(this).data('track');

      if (track) {
        var favourite = !panel.imageConfig[track.id].favourite &&  track.fav ? 1 : // Making a track a favourite
                         panel.imageConfig[track.id].favourite && !track.fav ? 0 : // Making a track not a favourite
                         false;
        
        if (panel.imageConfig[track.id].renderer !== track.renderer) {
          imageConfig[track.id] = { renderer: track.renderer };
          diff = true;
        }
        
        if (favourite !== false) {
          imageConfig[track.id] = imageConfig[track.id] || {};
          imageConfig[track.id].favourite = favourite;
          diff = true;
        }
      }
    });

    this.elLk.viewConfigInputs.each(function () {
      if (viewConfig[this.name] && viewConfig[this.name] !== 'off') {
        return;
      }
      var value = this.type === 'checkbox' || this.type === 'radio' ? this.checked ? this.value : 'off' : this.type === 'select-multiple' ? $('option:selected', this).map(function () { return this.value; }).toArray() : this.value;
      
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
    });

    if (diff === true || typeof saveAs !== 'undefined') {

      if (saveAs === true) {
        return { imageConfig: imageConfig, viewConfig: viewConfig };
      }

      $.extend(true, this.imageConfig, imageConfig);
      $.extend(true, this.viewConfig,  viewConfig);

      this.updatePage($.extend(saveAs, { 'image_config': JSON.stringify(imageConfig), 'view_config': JSON.stringify(viewConfig), 'menu_ids': JSON.stringify(menu_ids), 'matrix': matrix }), delayReload);
      
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
      data: $.extend(data, Ensembl.coreParams), 
      traditional: true,
      dataType: 'json',
      async: false,
      success: function (json) {
        if (json.existingConfig) {
          panel.updateSavedConfig(json.existingConfig);
        }
        
        if (json.updated) {
          Ensembl.EventManager.trigger('queuePageReload', panel.component, !delayReload);
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
    
    if (configIds.saved) {
      for (var i in configIds.saved) {
        if (!this.elLk.existingConfigs.children('.' + configIds.saved[i].value).length) {
          $('<option>', configIds.saved[i]).appendTo(this.elLk.existingConfigs);
        }
      }
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
      
      if (this.params.species === Ensembl.species) {
        this.el.addClass('active');
      } else {
        this.el.removeClass('active').data('reload', true);
      }
    }
  },
  
  makeSortable: function () {
    var panel = this;
    
    for (var i in this.params.order) {
      this.params.order[i] = parseFloat(this.params.order[i], 10);
    }
    
    this.elLk.trackOrderList.sortable({
      axis: 'y',
      containment: 'parent',
      update: function (e, ui) {
        var trackId = ui.item.data('trackName').replace(' ', '.');
        var prevIds = $.makeArray(ui.item.prevAll().map(function(i, track) {
          return ($(track).data('trackName') || '').replace(' ', '.');
        }));

        Ensembl.EventManager.triggerSpecific('changeTrackOrder', panel.component, panel.params.species, trackId, prevIds);
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
    var div, divs, show, menu, ul, tracks, track, i, j, match, type;
    
    function search(n, name, desc, li) {
      match = name.indexOf(panel.query) !== -1;
      
      if (match || desc.indexOf(panel.query) !== -1) {
        if (!panel.imageConfig[n]) {
          li                   = $(li).appendTo(menu);
          panel.imageConfig[n] = { renderer: 'off', favourite: !!panel.favourites[type] && panel.favourites[type][n] };
          
          added.push(li[0]);
          panel.externalFavourite(n, li);
          panel.tracks[n].el = li.data('track', panel.tracks[n]);
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
      
      for (type in this.params.tracksByType) {
        show   = false;
        div    = this.elLk.configDivs.filter('.' + type);
        ul     = div.find('ul.config_menu');
        tracks = this.params.tracksByType[type];
        i      = tracks.length;
        
        while (i--) {
          menu = ul.eq(i);
          
          for (j in tracks[i]) {
            track = this.tracks[tracks[i][j]];
            search(track.id, track.name, track.desc, track.el || track.html);
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

    desc.find('._dyna_load').removeClass('_dyna_load').dynaLoad({complete: function () { this.externalLinks(); }});
    
    this.elLk.help = this.elLk.help.add(button).filter('.open');
  }, 
  
  changeFavourite: function (trackId, selected, type, id) {
    var li, div;
    
    if (this.tracks[trackId].el) {
      li = this.tracks[trackId].el.toggleClass('fav');
      this.tracks[trackId].fav = !this.tracks[trackId].fav;
    }
    
    if (this.sortable) {
      this.elLk.trackOrderList.children('.' + trackId).toggleClass('fav');
    }
    
    if (this.elLk.links.filter('.active').children('a')[0].className === 'favourite_tracks') {
      div = li.hide().parents('div.config'); // Always hide, since the only way a click can come here is from a selected track
      
      if (!div.find('li:visible').length) {
        div.hide();
      }
      
      if (!this.elLk.tracks.filter('.fav').length) {
        this.elLk.favouritesMsg.show();
      }
    }
    
    if (this.id !== id) {
      if (type) {
        this.externalFavourites[trackId] = [ selected, type ];
      }
      
      if (this.imageConfig[trackId]) {
        this.imageConfig[trackId].favourite = selected;
      }
    }
    
    li = div = null;
  },
  
  externalFavourite: function (trackId, el) {
    if (typeof this.externalFavourites[trackId] !== 'undefined') {
      this.imageConfig[trackId].favourite = this.externalFavourites[trackId][0];
      
      if (this.tracks[trackId].fav !== this.imageConfig[trackId].favourite) {
        el[this.imageConfig[trackId].favourite ? 'addClass' : 'removeClass']('fav');
        this.tracks[trackId].fav = this.imageConfig[trackId].favourite;
      }
      
      delete this.externalFavourites[trackId];
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
    
    for (var trackId in tracks) {
      if (this.tracks[trackId]) { // FIXME: subtracks aren't included in main panel
        this.changeTrackRenderer(this.tracks[trackId].el, tracks[trackId]);
        this.imageConfig[trackId].renderer = tracks[trackId];
      }
    }
  },
  
  // Called when a view config option is changed, to make sure the identical option is updated in other Configurator panels
  syncViewConfig: function (panelId, filterClass, name, prop, value) {
    var panel = this;
    
    if (this.id !== panelId) {
      var el = this.elLk.viewConfigs.filter('.' + filterClass).find(':input[name=' + name + ']').prop(prop, value);
      
      if (this.viewConfig[name]) {
        this.viewConfig[name] = prop === 'checked' ? value ? el[0].value : 'off' : value;
      }
      
      if (el.attr('name') === 'select_all') {
        el.parents('fieldset').find('input[type=checkbox]').prop('checked', value).each(function () {
          panel.viewConfig[this.name] = value ? this.value : 'off';
        });
      }
      
      el = null;
    }
  },
  
  // Called when track order is changed on the image
  externalOrder: function (trackId, prevTrackId) {

    if (!this.elLk.trackOrderList.children().length) {
      var active = this.elLk.links.filter('.active').children('a')[0].className;
      this.show('track_order');
      this.getContent();
      this.show(active);
    }

    var track = this.elLk.trackOrderList.find('.' + trackId);
    var prev  = prevTrackId ? this.elLk.trackOrderList.find('.' + prevTrackId) : false;

    if (!track.length) {
      return;
    }

    if (prev && prev.length) {
      track.insertAfter(prev);
    } else {
      track.parent().prepend(track);
    }

    track = prev = null;
  },

  // Called when track order or configs are reset on the image
  externalReset: function() {
    this.el.empty().removeClass('active');
  },

  // new save configurations stuff
  initConfigList: function() {
    this.elLk.configSelector.off().on('change', {panel: this}, function(e) {

      var selector = $(this);
      var selected = selector.val();

      if (selected === 'current') {
        return;
      }

      if (selector.find('option[value=current]').prop('disabled') || window.confirm('Your current configuration is unsaved and will be lost if you continue.')) {
        if (selected === 'public') {
          e.data.panel.openPublicConfigs();
        } else {
          selector.data('selected', selected);
          e.data.panel.setConfig(selected);
          return;
        }
      }

      selector.find('option[value=' + selector.data('selected') + ']').prop('selected', true);
    });

    this.elLk.configSaveInput.last().append('<a class="left-margin" href="#">Cancel</a>').find('a').on('click', {panel: this}, function(e) {
      e.preventDefault();
      e.data.panel.elLk.configSaveInput.find('input').trigger('reset').end().hide();
      e.data.panel.elLk.configSelector.parent().show();
    }).end().end().first().find('input').on('keydown mousedown', function() { // clear the default value with the first keydown/mousedown
      if (this.value === this.defaultValue) {
        this.value = '';
      }
    });

    this.elLk.configForm.on('submit', {panel: this, input: this.elLk.configSaveInput.find('input[type=text]')[0] }, function(e) {
      e.preventDefault();
      if (e.data.input.value === e.data.input.defaultValue) {
        $(e.data.input).selectRange(0, e.data.input.defaultValue.length);
      } else {
        e.data.panel.configSave(true, e.data.input.value);
      }
    });

    this.refreshConfigList();
  },

  refreshConfigList: function() {
    this.elLk.configDropdown.removeClass('hidden').css('opacity', 0.5);
    this.elLk.configSelector.parent().show();
    this.elLk.configSaveLink.add(this.elLk.configSaveAsLink).hide();
    this.elLk.configSaveInput.hide();

    $.ajax({
      url: this.params['config_selector_url'],
      dataType: 'json',
      context: this,
      success: function(json) {

        // reset selector
        this.elLk.configSelector.empty().prop('disabled', false);

        // add default option
        this.elLk.configSelector.append('<option value="default">Default</option>');

        // current unsaved
        this.elLk.configSelector.append($('<option value="current">Current unsaved</option>').prop('disabled', json.selected !== 'current')
          .on('select', {link: this.elLk.configSaveAsLink, selector: this.elLk.configSelector}, function(e) {
            e.data.selector.data('selected', 'current');
            this.disabled = false;
            this.selected = true;
            e.data.link.html('Save current configuration').show();
          })
          .on('unselect', {link: this.elLk.configSaveAsLink, selector: this.elLk.configSelector, persistent: json.selected === 'current'}, function(e) {
            var prev = e.data.selector.data('selected');
            e.data.selector.find('option[value=' + prev + ']').prop('selected', true);
            if (!e.data.persistent) {
              e.data.link.hide();
              this.disabled = true;
            }
          })
        );

        // saved configs
        if (json.configs && json.configs.length) {

          this.elLk.configSelector.append($('<optgroup label="Saved configurations">').append($.map(json.configs, function(option) {
            return $('<option value="' + option.value + '">' + option.name + '</option>');
          })).find('option').on('select', {links: [this.elLk.configSaveLink, this.elLk.configSaveAsLink]}, function(e, initial) {
            if (!initial) {
              e.data.links[0].html('Save existing').show();
              e.data.links[1].html('Create new').show();
            }
            this.selected = true;
          }).on('unselect', {links: this.elLk.configSaveLink.add(this.elLk.configSaveAsLink)}, function(e, initial) {
            e.data.links.hide();
          }).end());
        }

        // public configs
        // this.elLk.configSelector.append('<option value="public">Select from publically available configurations...</option>');

        // selected config
        this.elLk.configSelector.data('selected', json.selected).find('option[value=' + json.selected + ']').triggerHandler('select', true);

      },
      error: function() {
        this.elLk.configSelector.empty().append('<option>Error</option>').prop('disabled', true);
      },
      complete: function() {
        this.elLk.configDropdown.css('opacity', 1);
      }
    });
  },

  configSettingChanged: function(isConfigMatrix) {
    var changes = isConfigMatrix ? this.updateConfiguration(this.id) : this.updateConfiguration(true, true);
    this.elLk.configSelector.find(this.elLk.configSelector.val() === 'default' ? 'option[value=current]' : ':selected').trigger($.isEmptyObject(changes.imageConfig) && $.isEmptyObject(changes.viewConfig) ? 'unselect' : 'select');
  },

  configSave: function(isNew, configName) {
    var changes = this.updateConfiguration(true, true);

    if ($.isEmptyObject(changes.imageConfig) && $.isEmptyObject(changes.viewConfig) && this.elLk.configSelector.data('selected') !== 'current') {
      return;
    }

    if (isNew) {
      if (!configName) {
        this.elLk.configSaveInput.show().first().find('input').val(function() { return this.defaultValue; }).selectRange(0, function() { return this.defaultValue.length; });
        this.elLk.configSelector.parent().hide();
        return;
      } else {
        changes.configName = configName;
      }
    } else {
      changes.configId    = this.elLk.configSelector.val();
      changes.configName  = this.elLk.configSelector.find('option:selected').html();
    }

    this.elLk.configSelector.empty().append('<option>Applying...</option>').prop('disabled', true);

    $.ajax({
      url: this.params['config_save_url'],
      dataType: 'json',
      method: 'post',
      context: this,
      data: {config: JSON.stringify(changes)},
      success: function(json) {
        if (json.updated) {
          this.refreshConfigList();
          Ensembl.EventManager.trigger('queuePageReload', this.component, false, true);
        } else {
          this.showError('Error: Configuration settings could not be saved.');
        }
      },
      error: function() {
        this.showError('Error: Configuration settings could not be saved.');
      },
      complete: function() {
        this.elLk.configSelector.prop('disabled', false);
      }
    });
  },

  openPublicConfigs: function() { // TODO
  },

  setConfig: function(configName) {

    $.ajax({
      url: this.params['config_apply_url'],
      dataType: 'json',
      context: this,
      data: {apply: configName},
      success: function(json) {
        if (json.updated) {
          this.elLk.configSelector.empty().append('<option>Applying...</option>').prop('disabled', true);
          this.elLk.configSaveLink.add(this.elLk.configSaveAsLink).remove();
          Ensembl.redirect();
        }
        else {
          this.showError('Error: Configuration settings could not be applied.');
        }
      },
      error: function() {
        this.showError('Error: Configuration settings could not be applied.');
      }
    });
  },

  showError: function(message) {
    alert(message);
  },

  destructor: function () {
    this.imageConfig = this.searchCache = this.tracks = null;
    this.base.apply(this, arguments);
  }
});
