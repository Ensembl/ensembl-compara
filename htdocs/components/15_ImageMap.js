/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

Ensembl.Panel.ImageMap = Ensembl.Panel.Content.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    this.dragging         = false;
    this.panning          = false;
    this.clicking         = true;
    this.dragCoords       = {};
    this.dragRegion       = {};
    this.highlightRegions = {};
    this.areas            = [];
    this.draggables       = [];
    this.speciesCount     = 0;
    this.minImageWidth    = 500;
    this.labelWidth       = 0;
    this.boxCoords        = {}; // only passed to the backend as GET param when downloading the image to embed the red highlight box into the image itself
    
    function resetOffset() {
      delete this.imgOffset;
    }
    
    Ensembl.EventManager.register('highlightImage',     this, this.highlightImage);
    Ensembl.EventManager.register('mouseUp',            this, this.dragStop);
    Ensembl.EventManager.register('hashChange',         this, this.hashChange);
    Ensembl.EventManager.register('changeFavourite',    this, this.changeFavourite);
    Ensembl.EventManager.register('imageResize',        this, this.getContent);
    Ensembl.EventManager.register('windowResize',       this, resetOffset);
    Ensembl.EventManager.register('ajaxLoaded',         this, resetOffset); // Adding content could cause scrollbars to appear, changing the offset, but this does not fire the window resize event
    Ensembl.EventManager.register('changeWidth',        this, function () { this.params.updateURL = Ensembl.updateURL({ image_width: false }, this.params.updateURL); Ensembl.EventManager.trigger('queuePageReload', this.id); });
    Ensembl.EventManager.register('highlightAllImages', this, function () { if (!this.align) { this.highlightAllImages(); } });
  },
  
  init: function () {
    var panel   = this;
    var species = {};
    
    this.base();
    
    this.imageConfig        = $('input.image_config', this.el).val();
    this.lastImage          = Ensembl.images.total > 1 && this.el.parents('.image_panel')[0] === Ensembl.images.last;
    this.hashChangeReload   = this.lastImage || $('.hash_change_reload', this.el).length;
    this.zMenus             = {};
    
    this.params.highlight   = (Ensembl.images.total === 1 || !this.lastImage);
    
    this.elLk.container     = $('.image_container',   this.el);
    this.elLk.drag          = $('.drag_select',       this.elLk.container);
    this.elLk.map           = $('.json_imagemap',     this.elLk.container);
    var data                = this.loadJSON(this.elLk.map.html());
    this.elLk.areas         = data.out;
    this.elLk.exportMenu    = $('.iexport_menu',      this.elLk.container).appendTo('body').css('left', this.el.offset().left);
    this.elLk.resizeMenu    = $('.image_resize_menu', this.elLk.container).appendTo('body').css('left', this.el.offset().left);
    this.elLk.img           = $('img.imagemap',       this.elLk.container);
    this.elLk.hoverLabels   = $('.hover_label',       this.elLk.container);
    this.elLk.boundaries    = $('.boundaries',        this.elLk.container);
    this.elLk.toolbars      = $('.image_toolbar',     this.elLk.container);
    this.elLk.popupLinks    = $('a.popup',            this.elLk.toolbars);

    this.vertical = this.elLk.img.hasClass('vertical');
    if(data.flags) {
      this.multi    = data.flags.multi;
      this.align    = data.flags.align;
    }
    
    this.makeImageMap();
    this.makeHoverLabels();
    this.initImageButtons();
    
    if (!this.vertical) {
      this.makeResizable();
    }
    
    species[this.id] = this.getSpecies();
    $.extend(this, Ensembl.Share);
    this.shareInit({ species: species, type: 'image', positionPopup: this.positionToolbarPopup });
    
    if (this.elLk.boundaries.length) {
      Ensembl.EventManager.register('changeTrackOrder', this, this.externalOrder);
      
      if (this.elLk.img[0].complete) {
        this.makeSortable();
      } else {
        this.elLk.img.on('load', function () { panel.makeSortable(); });
      }
    }
    
    if (typeof FileReader !== 'undefined') {
      this.dropFileUpload();
    }
    
    $('a',         this.elLk.toolbars).helptip({ track: false });
    $('a.iexport', this.elLk.toolbars).data('popup', this.elLk.exportMenu);
    $('a.resize',  this.elLk.toolbars).data('popup', this.elLk.resizeMenu);
    
    this.elLk.popupLinks.on('click', function () {
      var popup = $(this).data('popup');
      
      panel.elLk.popupLinks.map(function () { return ($(this).data('popup') || $()).filter(':visible')[0]; }).not(popup).hide();
      
      if (popup && !popup.hasClass('share_page')) {
        panel.positionToolbarPopup(popup, this).toggle();
      }
      
      popup = null;
      
      return false;
    });

    $('a.image_resize', this.elLk.resizeMenu).on('click', function () {
      if (!$(this).has('.current').length) {
        panel.resize(parseInt($(this).text(), 10) || Ensembl.imageWidth());
      }
      
      return false;
    });

    if (this.elLk.boundaries.length && this.draggables.length) {
      this.panning = Ensembl.cookie.get('ENSEMBL_REGION_PAN') === '1';
      this.elLk.toolbars.first().append([
        '<div class="scroll-switch">',
          '<span>Drag/Select:</span>',
          '<div><button title="Scroll to a region" class="dragging on"></button></div>',
          '<div class="last"><button title="Select a region" class="dragging"></button></div>',
        '</div>'].join('')).find('button').helptip().on('click', function() {
        var flag = $(this).hasClass('on');
        if (flag !== panel.panning) {
          $(this).parent().parent().find('div').toggleClass('selected');
          panel.panning = flag;
          Ensembl.cookie.set('ENSEMBL_REGION_PAN', flag ? '1' : '0');
          if (flag) {
            panel.selectArea(false);
            panel.removeZMenus();
          }
        }
      }).filter(panel.panning ? '.on' : ':not(.on)').parent().addClass('selected');
    }
  },

  loadJSON: function(str) {
    // this will be more complex when compression is used
    if(!str) { return { out: [], flags: {} }; }
    raw = $.parseJSON(str);
    out = [];
    flags = {};
    $.each(raw,function(i,val) {
      data = { shape: val[0], coords: val[1], attrs: val[2] };
      klass = {};
      if(data.attrs.klass) {
        $.each(data.attrs.klass,function(i,x) {
          klass[x] = 1;
          flags[x] = 1;
        });
      }
      data.klass = klass;
      out.push(data);
    });

    return { out: out, flags: flags };
  },

  initImageButtons: function() {
    var panel = this;

    this.el.find('._reset').on('click', function(e) {
      e.preventDefault();
      $.ajax({
        context: panel,
        url: this.href,
        type: 'post',
        success: function() {
          Ensembl.EventManager.triggerSpecific('resetConfig', 'modal_config_' + this.id.toLowerCase());
          Ensembl.EventManager.trigger('resetMessage');
          this.getContent();
        },
        data: {
          image_config: panel.imageConfig
        }
      });
    });
  },

  hashChange: function (r) {
    var reload = this.hashChangeReload;
    
    this.params.updateURL = Ensembl.urlFromHash(this.params.updateURL);
    
    if (Ensembl.images.total === 1) {
      this.highlightAllImages();
    } else if (!this.multi && this.highlightRegions[0]) {
      var range = this.highlightRegions[0][0].region.range;
      r = r.split(/\W/);
      
      if (parseInt(r[1], 10) < range.start || parseInt(r[2], 10) > range.end || range.chr !== r[0]) {
        reload = true;
      }
    }
    
    if (reload) {
      this.base();
    }
    
    if (this.align) {
      Ensembl.EventManager.trigger('highlightAllImages');
    }
  },
  
  getContent: function (url, el, params, newContent, attrs) {
    // If the panel contains an ajax loaded sub-panel, this function will be reached before ImageMap.init has been completed.
    // Make sure that this doesn't cause an error.
    if (this.imageConfig) {
      this.elLk.exportMenu.add(this.elLk.labelLayers).add(this.elLk.hoverLayers).add(this.elLk.resizeMenu).remove();

      this.removeZMenus();
      this.removeShare();
    }
    
    if (this.elLk.boundariesPanning) {
      attrs = attrs || {};
      attrs.background = true;
    }

    this.base.call(this, url, el, params, newContent, attrs);
    
    this.xhr.done(function (html) {
      if (!html) {
        delete Ensembl.images[this.imageNumber];
        Ensembl.EventManager.trigger('highlightAllImages');
      }
    });
  },
  
  makeImageMap: function () {
    var panel = this;
    
    var highlight = !!(window.location.pathname.match(/\/Location\//) && !this.vertical);
    var rect      = [ 'l', 't', 'r', 'b' ];
    var speciesNumber, c, r, start, end, scale;
    
    $.each(this.elLk.areas,function () {
      c = { a: this };
      
      if (this.shape && this.shape.toLowerCase() !== 'rect') {
        c.c = [];
        $.each(this.coords, function () { c.c.push(parseInt(this, 10)); });
      } else {
        $.each(this.coords, function (i) { c[rect[i]] = parseInt(this, 10); });
      }
      
      panel.areas.push(c);
      
      if (this.klass.drag || this.klass.vdrag) {
        // r = [ '#drag', image number, species number, species name, region, start, end, strand ]
        r        = c.a.attrs.href.split('|');
        start    = parseInt(r[5], 10);
        end      = parseInt(r[6], 10);
        scale    = (end - start + 1) / (this.vertical ? (c.b - c.t) : (c.r - c.l)); // bps per pixel on image
        
        c.range = { chr: r[4], start: start, end: end, scale: scale, vertical: this.vertical };
        
        panel.draggables.push(c);
        
        if (highlight === true) {
          r = this.attrs.href.split('|');
          speciesNumber = parseInt(r[1], 10) - 1;
          
          if (panel.multi || !speciesNumber) {
            if (!panel.highlightRegions[speciesNumber]) {
              panel.highlightRegions[speciesNumber] = [];
              panel.speciesCount++;
            }
            
            panel.highlightRegions[speciesNumber].push({ region: c });
            panel.imageNumber = parseInt(r[2], 10);
            
            Ensembl.images[panel.imageNumber] = Ensembl.images[panel.imageNumber] || {};
            Ensembl.images[panel.imageNumber][speciesNumber] = [ panel.imageNumber, speciesNumber, parseInt(r[5], 10), parseInt(r[6], 10) ];
          }
        }
      }
    });

    if (Ensembl.images.total) {
      this.highlightAllImages();
    }
    
    this.elLk.drag.on({
      mousedown: function (e) {

        if (!e.which || e.which === 1) { // Only draw the drag box for left clicks.
          panel.dragStart(e);
        }
        
        return false;
      },
      mousemove: function(e) {

        if (panel.dragging !== false) {
          return;
        }
        
        var area = panel.getArea(panel.getMapCoords(e));
        var tip;

        // change the cursor to pointer for clickable areas
        $(this).toggleClass('drag_select_pointer', !(!area || area.a.klass.label || area.a.klass.drag || area.a.klass.vdrag || area.a.klass.hover));

        // Add helptips on navigation controls in multi species view
        if (area && area.a && area.a.klass.nav) {
          if (tip !== area.a.attrs.alt) {
            tip = area.a.attrs.alt;
            
            if (!panel.elLk.navHelptip) {
              panel.elLk.navHelptip = $('<div class="ui-tooltip helptip-bottom"><div class="ui-tooltip-content"></div></div>');
            }
            
            panel.elLk.navHelptip.children().html(tip).end().appendTo('body').position({
              of: { pageX: panel.imgOffset.left + area.l + 10, pageY: panel.imgOffset.top + area.t - 48, preventDefault: true }, // fake an event
              my: 'center top'
            });
          }
        } else {
          if (panel.elLk.navHelptip) {
            panel.elLk.navHelptip.detach().css({ top: 0, left: 0 });
          }
        }
      },
      mouseleave: function(e) {
        if (e.relatedTarget) {

          if (panel.elLk.navHelptip) {
            panel.elLk.navHelptip.detach();
          }

        }
      },
      click: function (e, e2) {
        if (panel.clicking) {
          panel.makeZMenu(e2 || e, panel.getMapCoords(e2 || e));
        } else {
          panel.clicking = true;
        }
      }
    });
  },
  
  makeHoverLabels: function () {
    var panel = this;

    this.elLk.labelLayers = $();
    this.elLk.hoverLayers = $();

    $.each(this.areas, function() {
      if (!this.a) {
        return;
      }
      if (this.a.klass.label) {
        var hoverLabel = '';
        $.each(this.a.klass,function(k,v) {
          if(k != 'label') {
            hoverLabel += k;
          }
        });
        hoverLabel = panel.elLk.hoverLabels.filter('.' + hoverLabel);

        if (hoverLabel.length) {
          // add a div layer over the label, and append the hover menu to the layer. Hover menu toggling is controlled by CSS.
          panel.elLk.labelLayers = panel.elLk.labelLayers.add(
            $('<div class="label_layer">').append('<div class="label_layer_bg">').append(hoverLabel).appendTo(panel.elLk.container).data({area: this})
          );
        }

        panel.labelWidth = Math.max(panel.labelWidth, this.a.coords[2]);

        hoverLabel = null;

      } else if (this.a.klass.hover) {

        panel.elLk.hoverLayers = panel.elLk.hoverLayers.add(
          $('<div class="hover_layer">').appendTo(panel.elLk.container).data({area: this}).on('click', function(e) {
            panel.clicking = true;
            panel.elLk.drag.triggerHandler('click', e);
          }
        ));
      }

      $a = null;
    });

    // apply css positions to the hover layers
    this.positionLayers();

    this.elLk.hoverLabels.each(function() {

      // position hover menus to the right of the layer and init the tab styled icons inside the hover menus
      $(this).css('left', function() { return $(this.parentNode).width(); }).find('._hl_icon').tabs($(this).find('._hl_tab'));

    // init config tab, fav icon and close icon
    }).find('a.config').on('click', function () {
      var config  = this.rel;
      var update  = this.href.split(';').reverse()[0].split('='); // update = [ trackId, renderer ]
      var fav     = '';
      var $this   = $(this);

      if ($this.hasClass('favourite')) {
        fav = $this.hasClass('selected') ? 'off' : 'on';
        Ensembl.EventManager.trigger('changeFavourite', update[0], fav === 'on');
      } else {
        $this.parents('.label_layer').addClass('hover_label_spinner');
      }

      $.ajax({
        url: this.href + fav,
        dataType: 'json',
        success: function (json) {
          if (json.updated) {
            Ensembl.EventManager.triggerSpecific('changeConfiguration', 'modal_config_' + config, update[0], update[1]);
            Ensembl.EventManager.trigger('reloadPage', panel.id);
          }
        }
      });
      
      $this = null;

      return false;
    }).end().find('input._copy_url').on('click focus blur', function(e) {
      $(this).val(this.defaultValue).select().parents('.label_layer').toggleClass('hover', e.type !== 'blur');
    });
  },

  positionLayers: function() {
    if(!this.elLk.img || !this.elLk.img.length) { return; }
    var offsetContainer = this.elLk.container.offset();
    var offsetImg       = this.elLk.img.offset();
    var top             = offsetImg.top - offsetContainer.top - 1; // 1px border
    var left            = offsetImg.left - offsetContainer.left - 1;
    var right           = this.labelWidth;

    this.elLk.labelLayers.each(function() {
      var $this = $(this);
      var area  = $this.data('area');

      $this.css({
        left:   left + area.l,
        top:    top + area.t,
        height: area.b - area.t,
        width:  right - area.l
      });

      area = $this = null;
    });

    this.elLk.hoverLayers.each(function() {
      var $this = $(this);
      var area  = $this.data('area');

      $this.css({
        left:   left + area.l,
        top:    top + area.t,
        height: area.b - area.t,
        width:  area.r - area.l
      });

      area = $this = null;
    });
  },
  
  makeResizable: function () {
    var panel = this;
    
    function resizing(e, ui) {
      panel.imageResize = Math.floor(ui.size.width / 100) * 100; // The image_container has a border, which causes ui.size.width to increase by the border width.
      resizeHelptip.apply(this, [ ui.helper ].concat(e.type === 'resizestart' ? [ 'Drag to resize', e.pageY ] : panel.imageResize + 'px'));
    }
    
    function resizeHelptip(el, content, y) {
      if (typeof y === 'number') {
        el.data('y', y);
      } else {
        y = el.data('y');
      }
      
      el.html('<div class="bg"></div><div class="ui-tooltip"><div class="ui-tooltip-content"></div></div>').find('.ui-tooltip-content').html(content).parent().css('top', function () {
        return y - el.offset().top - $(this).outerHeight(true) / 2;
      });
      
      el = null;
    }
    
    this.elLk.container.resizable({
      handles: 'e',
      grid:    [ 100, 0 ],
      minWidth: this.minImageWidth,
      maxWidth: $(window).width() - this.el.offset().left,
      helper:   'image_resize_overlay',
      start:    resizing,
      resize:   resizing,
      stop:     function (e, ui) {
        if (ui.originalSize.width === ui.size.width) {
          $(this).css({ width: panel.imageResize, height: '' });
        } else {
          panel.resize(panel.imageResize);
        }
      }
    });
  },
  
  makeSortable: function () {
    var panel      = this;
    var wrapperTop = $('.boundaries_wrapper', this.el).position().top;
    var ulTop      = this.elLk.boundaries.position().top + wrapperTop - (Ensembl.browser.ie7 ? 3 : 0); // IE7 reports li.position().top as 3 pixels higher than other browsers, so offset that here.
    var lis        = []; // just a throwaway list to allocate areas to their respective tracks

    this.elLk.boundaries.children().each(function (i) {
      var li  = $(this);
      var t   = li.position().top + ulTop;
      var ref = []; // reference for array containing areas for a track that will be populated later

      li.data({ areas: ref, position: i, top: li.offset().top });
      lis.push({ top: Math.floor(t), bottom: Math.ceil(t + li.height()), areas: ref });

      li = null;
    });

    $.each(this.areas, function () {

      assignArea:
      for (var i = 0; i <= 10; i++) { // this is to overcome an apparent drawing code bug that areas sometimes are not completely enclosed inside a track's li
        for (var j = lis.length - 1; j >= 0; j--) {
          if (lis[j].top <= this.t + i && lis[j].bottom >= this.b - i) {
            lis[j].areas.push(this);
            break assignArea;
          }
        }
      }
    });

    this.elLk.boundaries.each(function () {
      $(this).data('species', this.className.split(' ')[0]);
    }).sortable({
      axis:   'y',
      handle: 'div.handle',
      revert: 200,
      helper: 'clone',
      placeholder: 'placeholder',
      start: function (e, ui) {
        panel.sortStart(e, ui);
      },
      stop: function (e, ui) {
        panel.sortStop(e, ui);
      },
      update: function (e, ui) {
        panel.sortUpdate(e, ui);
      }
    }).css('visibility', 'visible').find('div.handle').on({
      mousedown: function() {
        $(this.parentNode).stop().animate({opacity: 0.8}, 200);
      },
      mouseup: function() {
        $(this.parentNode).stop().animate({opacity: 1}, 200);
      }
    });
  },

  sortStart: function (e, ui) {

    // make the placeholder similar to the actual track but slightly faded so the saturated background colour beneath gives it a highlighted effect
    ui.placeholder.css({
      backgroundImage:     ui.item.css('backgroundImage'),
      backgroundPosition:  ui.item.css('backgroundPosition'),  // Firefox
      backgroundPositionY: ui.item.css('backgroundPositionY'), // IE (Chrome works with either)
      height:              ui.item.height(),
      opacity:             0.8
    }).html(ui.item.html()).addClass(ui.item.prop('className'));

    // add some transparency to the helper (already a clone of actual track) that moves with the mouse
    ui.helper.stop().css({opacity: 0.8}).addClass('helper');

    // css deals with the rest of the things
    $(document.body).addClass('track-reordering');

    this.dragging = true;
  },

  sortStop: function (e, ui) {
    ui.item.stop().animate({opacity: 1}, 200);
    $(document.body).removeClass('track-reordering');
    this.dragging = false;
  },

  sortUpdate: function(e, ui) {

    var prev  = (ui.item.prev().prop('className') || '').replace(' ', '.');
    var track = ui.item.prop('className').replace(' ', '.');

    Ensembl.EventManager.triggerSpecific('changeTrackOrder', 'modal_config_' + this.id.toLowerCase(), track, prev);

    this.afterSort(ui.item.parent().data('species'), track, prev);
  },

  externalOrder: function(species, trackId, prevTrackIds) {
    var track = this.elLk.boundaries.find('li.' + trackId);
    var prev  = [];

    // there is a possibility that immediate previous track according to the config panel is not actually drawn by the drawing code,
    // in that case, find the next one in the list that's present on the image.
    for (var i in prevTrackIds) {
      prev = this.elLk.boundaries.find('li.' + prevTrackIds[i]);
      if (prev.length) {
        break;
      }
    }

    if (track.length) {
      if (prev.length) {
        track.insertAfter(prev);
      } else {
        track.parent().prepend(track);
      }
    }

    this.afterSort(species, trackId, prevTrackIds[0] || '');

    track = prev = null;
  },

  afterSort: function(species, track, prev) {
    this.positionAreas();
    this.positionLayers();
    this.removeShare();
    Ensembl.EventManager.trigger('removeShare');

    this.saveSort(species, track, prev);
  },

  saveSort: function(species, track, prev) {

    $.ajax({
      url:  '/' + species + '/Ajax/track_order',
      type: 'post',
      data: {
        image_config: this.imageConfig,
        track: track,
        prev: prev
      }
    });
  },

  positionAreas: function () {
    var tracks = this.elLk.boundaries.children();

    tracks.each(function (i) {
      var li = $(this);
      var top, move;

      if (i !== li.data('position')) {
        top  = li.offset().top;
        move = top - li.data('top'); // Up is positive, down is negative

        $.each(li.data('areas'), function () {
          this.t += move;
          this.b += move;
        });

        li.data({ top: top, position: i });
      }

      li = null;
    });

    tracks = null;
  },

  changeFavourite: function (trackId, on) {
    this.elLk.hoverLabels.filter('.' + trackId).find('a.favourite').toggleClass('selected', on);
  },
  
  dragStart: function (e) {
    var panel = this;
    
    this.dragCoords.map    = this.getMapCoords(e);
    this.dragCoords.page   = { x: e.pageX, y : e.pageY };
    this.dragCoords.offset = { x: e.pageX - this.dragCoords.map.x, y: e.pageY - this.dragCoords.map.y }; // Have to use this instead of the map coords because IE can't cope with offsetX/Y and relative positioned elements
    
    this.dragRegion = this.getArea(this.dragCoords.map, true);
    
    if (this.dragRegion) {
      this.mousemove = function (e2) {
        panel.dragging = e; // store mousedown event
        panel.drag(e2);
        return false;
      };
      
      this.elLk.drag.on('mousemove', this.mousemove);
    }
  },
  
  dragStop: function (e) {
    var diff, range;
    
    if (this.mousemove) {
      this.elLk.drag.off('mousemove', this.mousemove);
      this.mousemove = false;
    }
    
    if (this.dragging !== false) {
      if (this.elLk.boundariesPanning) {

        this.dragging = false;
        this.clicking = false;

        this.elLk.boundariesPanning.helptip('destroy');

        if (!this.newLocation) {
          this.elLk.boundariesPanning.parent().remove();
          this.elLk.boundariesPanning = false;
          return;
        }

        this.elLk.boundariesPanning.parent().append('<div class="spinner">');

        Ensembl.updateLocation(this.newLocation);

      } else {

        diff = {
          x: e.pageX - this.dragCoords.page.x,
          y: e.pageY - this.dragCoords.page.y
        };
        
        // Set a limit below which we consider the event to be a click rather than a drag
        if (Math.abs(diff.x) < 3 && Math.abs(diff.y) < 3) {
          this.clicking = true; // Chrome fires mousemove even when there has been no movement, so catch clicks here
        } else {
          range = this.vertical ? { r: diff.y, s: this.dragCoords.map.y } : { r: diff.x, s: this.dragCoords.map.x };
          
          this.makeZMenu(e, range, { onclose: function() { this.selectArea(false); }, context: this });
          
          this.dragging = false;
          this.clicking = false;
        }
      }
    }
  },
  
  drag: function (e) {

    if (this.panning) {
      this.panImage(e);
    } else {
      this.selectArea(e);
    }
  },

  panImage: function(e) {

    if (!this.elLk.boundariesPanning) {

      this.elLk.boundariesPanning = $('<div class="boundaries_panning">')
        .appendTo(this.elLk.boundaries.parent())
        .append(this.elLk.boundaries.clone())
        .css({ left: this.dragRegion.l, width: this.dragRegion.r - this.dragRegion.l })
        .find('ul').find('li').css('marginLeft', -1 * this.dragRegion.l)
        .end().helptip({delay: 500, position: { at: 'center', of: this.el }});
    }

    var locationDisplacement = Math.min(this.dragRegion.range.start - 1, Math.round((e.pageX - this.dragCoords.page.x) * this.dragRegion.range.scale));

    if (locationDisplacement) {
      this.newLocation = this.dragRegion.range.chr + ':' + (this.dragRegion.range.start - locationDisplacement) + '-' + (this.dragRegion.range.end - locationDisplacement);
      this.elLk.boundariesPanning.helptip('option', 'content', this.newLocation).helptip('open');
    } else {
      this.newLocation = false;
      this.elLk.boundariesPanning.helptip('close');
    }

    this.elLk.boundariesPanning.css('left', locationDisplacement / this.dragRegion.range.scale + 'px');
  },
  
  resize: function (width) {
    this.params.updateURL = Ensembl.updateURL({ image_width: width }, this.params.updateURL);
    this.getContent();
  },
  
  makeZMenu: function (e, coords, params) {
    var area = coords.r ? this.dragRegion : this.getArea(coords);
   
    if (!area || area.a.klass.label) {
      return;
    }
    
    if (area.a.klass.nav) {
      Ensembl.redirect(area.a.attrs.href);
      return;
    }
    
    var id = 'zmenu_' + area.a.coords.join('_');
    var dragArea, range, location, fuzziness;
    
    if (e.shiftKey || area.a.klass.das || area.a.klass.group) {
      dragArea = this.dragRegion || this.getArea(coords, true);
      range    = dragArea ? dragArea.range : false;
      
      if (range) {
        location  = range.start + (range.scale * (range.vertical ? (coords.y - dragArea.t) : (coords.x - dragArea.l)));
        fuzziness = range.scale * 2; // Increase the size of the click so we can have some measure of certainty for returning the right menu
        
        coords.clickChr   = range.chr;
        coords.clickStart = Math.max(Math.floor(location - fuzziness), range.start);
        coords.clickEnd   = fuzziness > 1 ? Math.min(Math.ceil(location + fuzziness), range.end) : Math.max(coords.clickStart,Math.floor(location));
        
        id += '_multi';
      }
      
      dragArea = null;
    }
    
    Ensembl.EventManager.trigger('makeZMenu', id, $.extend({ event: e, coords: coords, area: area, imageId: this.id, relatedEl: area.a.id ? $('.' + area.a.id, this.el) : false }, params));
    
    this.zMenus[id] = 1;
  },

  removeZMenus: function() {

    for (var id in this.zMenus) {
      Ensembl.EventManager.trigger('destroyPanel', id);
    }
  },
  
  /**
   * Triggers events to highlight all images on the page
   */
  highlightAllImages: function () {
    var image = Ensembl.images[this.imageNumber + 1] || Ensembl.images[this.imageNumber];
    var args, i;
    
    for (i in image) {
      args = image[i];
      this.highlightImage.apply(this, args);
    }
    
    if (!this.align && Ensembl.images[this.imageNumber - 1]) {
      image = Ensembl.images[this.imageNumber];
      
      for (i in image) {
        args = image[i].slice();
        args.unshift('highlightImage');
        
        Ensembl.EventManager.trigger.apply(Ensembl.EventManager, args);
      }
    }
  },
  
  /**
   * Highlights regions of the image.
   * In MultiContigView, each image can have numerous regions to highlight - one per species
   *
   * redbox:  Dotted red line outlining the draggable region of an image. 
   *          Only shown where an image displays a region contained in another region.
   *          In practice this means redbox never appears on the first image on the page.
   *
   * redbox2: Solid red line outlining the region of an image displayed on the next image.
   *          If there is only one image, or the next image has an invalid coordinate system 
   *          (eg AlignSlice or whole chromosome), highlighting is taken from the r parameter in the url.
   */
  highlightImage: function (imageNumber, speciesNumber, start, end) {
    // Make sure each image is highlighted based only on itself or the next image on the page
    if (!this.draggables.length || this.vertical || imageNumber - this.imageNumber > 1 || imageNumber - this.imageNumber < 0) {
      return;
    }
    
    var i    = this.highlightRegions[speciesNumber].length;
    var link = true; // Defines if the highlighted region has come from another image or the url
    var highlight, coords;
    
    while (i--) {
      highlight = this.highlightRegions[speciesNumber][i];
      
      if (!highlight.region.a) {
        break;
      }
      
      // Highlighting base on self. Take start and end from Ensembl core parameters
      if (this.imageNumber === imageNumber) {
        // Don't draw the redbox on the first imagemap on the page
        if (this.imageNumber !== 1) {
          this.highlight(highlight.region, 'redbox', speciesNumber, i);
        }
        
        if (speciesNumber && Ensembl.multiSpecies[speciesNumber]) {
          start = Ensembl.multiSpecies[speciesNumber].location.start;
          end   = Ensembl.multiSpecies[speciesNumber].location.end;
        } else {
          start = Ensembl.location.start;
          end   = Ensembl.location.end;
        }
        
        link = false;
      }
      
      coords = {
        t: highlight.region.t + 2,
        b: highlight.region.b - 2,
        l: ((start - highlight.region.range.start) / highlight.region.range.scale) + highlight.region.l,
        r: ((end   - highlight.region.range.start) / highlight.region.range.scale) + highlight.region.l
      };
      
      // Highlight unless it's the bottom image on the page
      if (this.params.highlight) {
        this.updateExportMenu(coords, speciesNumber, imageNumber);
        this.highlight(coords, 'redbox2', speciesNumber, i);
      }
    }
  },
  
  highlight: function (coords, cl, speciesNumber, multi) {
    var w = coords.r - coords.l + 1;
    var h = coords.b - coords.t + 1;
    var originalClass, els;
    
    var style = {
      l: { left: coords.l, width: 1, top: coords.t, height: h },
      r: { left: coords.r, width: 1, top: coords.t, height: h },
      t: { left: coords.l, width: w, top: coords.t, height: 1, overflow: 'hidden' },
      b: { left: coords.l, width: w, top: coords.b, height: 1, overflow: 'hidden' }
    };
    
    if (typeof speciesNumber !== 'undefined') {
      originalClass = cl;
      cl            = cl + '_' + speciesNumber + (multi || '');
    }
    
    els = $('.' + cl, this.el);
    
    if (!els.length) {
      els = $([
        '<div class="', cl, ' l"></div>', 
        '<div class="', cl, ' r"></div>', 
        '<div class="', cl, ' t"></div>', 
        '<div class="', cl, ' b"></div>'
      ].join('')).insertAfter(this.elLk.img);
    }
    
    els.each(function () {
      $(this).css(style[this.className.split(' ')[1]]);
    });
    
    if (typeof speciesNumber !== 'undefined') {
      els.addClass(originalClass);
    }
    
    els = null;
  },

  selectArea: function(e) {

    if (e === false) {
      this.elLk.selector && this.elLk.selector.hide();
      return;
    }

    var coords  = {};
    var x       = e.pageX - this.dragCoords.offset.x;
    var y       = e.pageY - this.dragCoords.offset.y;

    switch (x < this.dragCoords.map.x) {
      case true:  coords.l = x; coords.r = this.dragCoords.map.x; break;
      case false: coords.r = x; coords.l = this.dragCoords.map.x; break;
    }

    switch (y < this.dragCoords.map.y) {
      case true:  coords.t = y; coords.b = this.dragCoords.map.y; break;
      case false: coords.b = y; coords.t = this.dragCoords.map.y; break;
    }

    if (this.vertical || x < this.dragRegion.l) {
      coords.l = this.dragRegion.l;
    }
    if (this.vertical || x > this.dragRegion.r) {
      coords.r = this.dragRegion.r;
    }

    if (!this.vertical || y < this.dragRegion.t) {
      coords.t = this.dragRegion.t;
    }
    if (!this.vertical || y > this.dragRegion.b) {
      coords.b = this.dragRegion.b;
    }

    if (!this.elLk.selector || !this.elLk.selector.length) {
      this.elLk.selector = $('<div class="_selector selector"></div>').insertAfter(this.elLk.img).toggleClass('vertical', this.vertical).filter(':not(.vertical)')
      .append('<div class="left-border"></div><div class="right-border"></div>').on('click', function(e) {
        e.stopPropagation();
        $(document).off('.selectbox');
      }).on('mousedown', {panel: this}, function(e) {
        e.stopPropagation();
        e.preventDefault();

        $(document).on('mousemove.selectbox', {
          action  : e.target !== e.currentTarget ? e.target.className.match(/left/) ? 'left' : 'right' : 'move',
          x       : e.pageX,
          panel   : e.data.panel,
          width   : parseInt(e.data.panel.elLk.selector.css('width')),
          left    : parseInt(e.data.panel.elLk.selector.css('left'))
        }, function(e) {
          e.stopPropagation();

          var disp   = e.pageX - e.data.x;
          var coords = { left: e.data.left, width: e.data.width };

          disp = Math.max(disp, e.data.panel.dragRegion.l + 1 - coords.left);
          disp = Math.min(e.data.panel.dragRegion.r - coords.left - coords.width + 1, disp);

          switch (e.data.action) {
            case 'left':
              disp = Math.min(coords.width - 6, disp);
              coords.left = coords.left + disp;
              coords.width = coords.width - disp;
            break;
            case 'right':
              coords.width = Math.max(coords.width + disp, 6);
            break;
            case 'move':
              coords.left = coords.left + disp;
            break;
          }

          e.data.panel.elLk.selector.css(coords);
          e.data.panel.makeZMenu(e, { s: coords.left, r: coords.width });

        }).on('mouseup.selectbox click.selectbox', function(e) {
          $(this).off('.selectbox');
        })
      }).end();
    }

    this.elLk.selector.css({ left: coords.l, top: coords.t, width: coords.r - coords.l + 1, height: coords.b - coords.t - 1 }).show();
  },

  updateExportMenu: function(coords, speciesNumber, imageNumber) {
    var panel = this;

    if (this.imageNumber === imageNumber) {

      this.boxCoords[speciesNumber] = coords;

      this.elLk.exportMenu.find('a').each(function() {
        var href = $(this).data('href');
        if (!href) {
          $(this).data('href', this.href);
          href = this.href;
        }

        this.href = href + ';box=' + encodeURIComponent(JSON.stringify(panel.boxCoords));
      });
    }
  },

  getMapCoords: function (e) {
    this.imgOffset = this.imgOffset || this.elLk.img.offset();
    
    return {
      x: e.pageX - this.imgOffset.left - 1, // exclude the 1px borders
      y: e.pageY - this.imgOffset.top - 1
    };
  },
  
  getArea: function (coords, draggables) {
    var test  = false;
    var areas = draggables ? this.draggables : this.areas;
    var c;
    
    for (var i = 0; i < areas.length; i++) {
      c = areas[i];
      
      switch (c.a.shape.toLowerCase()) {
        case 'circle': test = this.inCircle(c.c, coords); break;
        case 'poly':   test = this.inPoly(c.c, coords); break;
        default:       test = this.inRect(c, coords); break;
      }
      
      if (test === true) {
        return $.extend({}, c);
      }
    }
  },
  
  inRect: function (c, coords) {
    return coords.x >= c.l && coords.x <= c.r && coords.y >= c.t && coords.y <= c.b;
  },
  
  inCircle: function (c, coords) {
    return (coords.x - c[0]) * (coords.x - c[0]) + (coords.y - c[1]) * (coords.y - c[1]) <= c[2] * c[2];
  },

  inPoly: function (c, coords) {
    var n = c.length;
    var t = 0;
    var x1, x2, y1, y2;
    
    for (var i = 0; i < n; i += 2) {
      x1 = c[i % n] - coords.x;
      y1 = c[(i + 1) % n] - coords.y;
      x2 = c[(i + 2) % n] - coords.x;
      y2 = c[(i + 3) % n] - coords.y;
      t += Math.atan2(x1*y2 - y1*x2, x1*x2 + y1*y2);
    }
    
    return Math.abs(t/Math.PI/2) > 0.01;
  },
  
  positionToolbarPopup: function (el, link) {
    var toolbar = $(link.parentNode);
    el.css({ top: toolbar.hasClass('bottom') ? toolbar.offset().top - el.outerHeight() : this.elLk.img.offset().top });
    link = toolbar = null;
    return el;
  },
  
  getSpecies: function () {
    var species = $.map(this.draggables, function (el) { return el.a.attrs.href.split('|')[3]; });
    
    if (species.length) {
      var unique = {};
      unique[Ensembl.species] = 1;
      $.each(species, function () { unique[this] = 1; });
      species = $.map(unique, function (i, s) { return s; });
    }
    
    return species.length > 1 ? species : undefined;
  },
  
  dropFileUpload: function () {
    var panel   = this;
    var el      = this.el[0];
    var reader  = new FileReader();
    var uploads = [];
    var r;
    
    function noop(e) {
      e.stopPropagation();
      e.preventDefault();
      return false;
    }
    
    function readFile(files) {
      if (!files.length) {
        if (r) {
          panel.hashChangeReload = true;
          Ensembl.updateLocation(r);
        }
        
        return;
      }
      
      var file = files.shift();
      
      if (file.size > 5 * Math.pow(1024, 2)) {
        return readFile(files);
      }
      
      reader.readAsText(file);
      
      reader.onloadend = function (e) {
        uploads.push($.ajax({
          url: '/' + Ensembl.species + '/UserData/DropUpload',
          data: { text: e.target.result, name: file.name },
          type: 'POST',
          success: function (response) {
            if (response) {
              r = response;
            }
            
            readFile(files);
          }
        }));
      };
    }
    
    el.addEventListener('dragenter', noop, false);
    el.addEventListener('dragexit',  noop, false);
    el.addEventListener('dragover',  noop, false);
    
    if ($('.drop_upload', this.el).length && !this.multi) {
      el.addEventListener('drop', function (e) {
        e.stopPropagation();
        e.preventDefault();
        readFile([].slice.call(e.dataTransfer.files).sort(function (a, b) { return a.name.toLowerCase() > b.name.toLowerCase(); }));
      }, false);
    } else {
      el.addEventListener('drop', noop, false);
    }
    
    el = null;
  }
});
