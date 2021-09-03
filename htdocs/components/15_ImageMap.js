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

Ensembl.Panel.ImageMap = Ensembl.Panel.Content.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    this.dragging           = false;
    this.panningAllowed     = false;
    this.panning            = false;
    this.clicking           = true;
    this.dragCoords         = {};
    this.dragRegion         = {};
    this.highlightRegions   = {};
    this.areas              = [];
    this.draggables         = [];
    this.speciesCount       = 0;
    this.minImageWidth      = 500;
    this.labelWidth         = 0;
    this.boxCoords          = {}; // only passed to the backend as GET param when downloading the image to embed the red highlight box into the image itself
    this.altKeyDragging     = false;
    this.allowHighlight     = !!(window.location.pathname.match(/\/Location\//));
    this.locationMarkingArea = false;
    this.highlightedTracks  = {};

    function resetOffset() {
      delete this.imgOffset;
    }
    
    Ensembl.EventManager.register('highlightImage',           this, this.highlightImage);
    Ensembl.EventManager.register('mouseUp',                  this, this.dragStop);
    Ensembl.EventManager.register('hashChange',               this, this.hashChange);
    Ensembl.EventManager.register('changeFavourite',          this, this.changeFavourite);
    // Ensembl.EventManager.register('changeHighlightTrackIcon', this, this.changeHighlightTrackIcon);
    Ensembl.EventManager.register('imageResize',              this, function () { if (this.xhr) { this.xhr.abort(); } this.getContent(); });
    Ensembl.EventManager.register('windowResize',             this, resetOffset);
    Ensembl.EventManager.register('ajaxLoaded',               this, resetOffset); // Adding content could cause scrollbars to appear, changing the offset, but this does not fire the window resize event
    Ensembl.EventManager.register('changeWidth',              this, function () { this.params.updateURL = Ensembl.updateURL({ image_width: false }, this.params.updateURL); Ensembl.EventManager.trigger('queuePageReload', this.id); });
    Ensembl.EventManager.register('highlightAllImages',       this, function () { if (!this.align) { this.highlightAllImages(); } });
    Ensembl.EventManager.register('markLocation',             this, this.markLocation);
  },
  
  init: function () {
    var panel   = this;
    var species = {};
    
    this.base();
    
    this.imageConfig        = $('input.image_config', this.el).val();
    this.viewConfig         = $('input.view_config', this.el).val();
    this.lastImage          = Ensembl.images.total > 1 && this.el.parents('.image_panel')[0] === Ensembl.images.last;
    this.hashChangeReload   = this.lastImage || $('.hash_change_reload', this.el).length;
    this.zMenus             = {};
    
    this.params.highlight   = (Ensembl.images.total === 1 || !this.lastImage);
    
    this.elLk.container     = $('.image_container',   this.el);
    this.elLk.drag          = $('.drag_select',       this.elLk.container);
    this.elLk.map           = $('.json_imagemap',     this.elLk.container);
    var data                = this.loadJSON(this.elLk.map.html());
    this.elLk.areas         = data.out;
    this.elLk.resizeMenu    = $('.image_resize_menu', this.elLk.container).appendTo('body').css('left', this.el.offset().left).attr('rel', this.id);
    this.elLk.img           = $('img.imagemap',       this.elLk.container);
    this.elLk.hoverLabels   = $('.hover_label',       this.elLk.container);
    this.elLk.boundaries    = $('.boundaries',        this.elLk.container);
    this.elLk.toolbars      = $('.image_toolbar',     this.elLk.container);
    this.elLk.exportButton  = this.elLk.toolbars.find('.export');
    this.elLk.popupLinks    = $('a.popup',            this.elLk.toolbars);

    this.vertical = this.elLk.img.hasClass('vertical');
    if(data.flags) {
      this.multi    = data.flags.multi;
      this.align    = data.flags.align;
    }
    
    this.makeImageMap();
    this.makeHoverLabels();
    this.initImageButtons();
    this.initImagePanning();
    this.initSelector();
    this.highlightLastUploadedUserDataTrack();
    this.markLocation(Ensembl.markedLocation);
    this.updateHighlightedTracks();

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

    this.highlightAllImages()
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
          Ensembl.EventManager.trigger('resetConfig');
          Ensembl.EventManager.trigger('resetMessage');
          this.getContent();
        },
        data: {
          image_config: panel.imageConfig,
          view_config: panel.viewConfig
        }
      });
    });
  },

  initImagePanning: function () {
    var panel = this;
    if (this.elLk.boundaries.length && this.draggables.length) {
      if(this.draggables[0].a.klass.noscroll) return;
      this.elLk.dragSwitch = this.elLk.toolbars.first().append([
        '<div class="scroll-switch">',
          '<span>Drag/Select:</span>',
          '<div><button title="Scroll to a region" class="dragging on"></button></div>',
          '<div class="last"><button title="Select a region" class="dragging"></button></div>',
        '</div>'].join('')).find('button').helptip().on('click', function() {
        var panning = $(this).hasClass('on');
        panel.setPanning(panning);
        if (panning) {
          panel.selectArea(false);
          panel.removeZMenus();
        }
      }).parent();
      this.panningAllowed = true;
      this.setPanning();
    }
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

  toggleLoading: function (flag) {
    if (flag) {
      this.selectArea(false);
      this.elLk.drag.filter(':not(:has(.image_spinner))').append('<div class="spinner image_spinner"><div>');
      this.elLk.toolbars.append('<div class="image_loading">Loading&#133;</div>');
    } else {
      this.elLk.drag.find('.image_spinner').add(this.elLk.toolbars.find('.image_loading')).remove();
    }
  },

  getContent: function (url, el, params, newContent, attrs) {
    // If the panel contains an ajax loaded sub-panel, this function will be reached before ImageMap.init has been completed.
    // Make sure that this doesn't cause an error.
    if (this.imageConfig) {
      $(this.elLk.labelLayers).add(this.elLk.hoverLayers).add(this.elLk.resizeMenu).remove();

      this.removeZMenus();
      this.removeShare();
    }

    if (this.elLk.drag && this.elLk.drag.length && $.contains(this.el[0], this.elLk.drag[0])) {
      this.toggleLoading(true);
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
    var rect  = [ 'l', 't', 'r', 'b' ];

    $.each(this.elLk.areas,function () {

      var speciesNumber, c, r, start, end, scale;

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
        r        = this.attrs.href.split('|');
        start    = parseInt(r[5], 10);
        end      = parseInt(r[6], 10);
        scale    = (end - start + 1) / (this.vertical ? (c.b - c.t) : (c.r - c.l)); // bps per pixel on image
        
        c.range = { chr: r[4], start: start, end: end, scale: scale, vertical: this.vertical };
        
        panel.draggables.push(c);
        
        if (panel.allowHighlight && !panel.vertical) {
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

    // boundary for location marking
    if (this.draggables.length) {
      this.locationMarkingArea = this.draggables[0];
    }

    if (Ensembl.images.total) {
      this.highlightAllImages();
    }
    
    this.elLk.drag.on({
      mousedown: function (e, e2) {
        e = e2 || e;

        if (!e.which || e.which === 1) { // Only draw the drag box for left clicks.
          panel.dragStart(e);
        }
        
        return false;
      },
      mousemove: function(e, e2) {

        e = e2 || e;

        if (panel.dragging !== false) {
          return;
        }
        
        var area = panel.getArea(panel.getMapCoords(e));
        var tip;

        // change the cursor to pointer for clickable areas
        $(this).toggleClass('drag_select_pointer', !(!area || area.a.klass.label || area.a.klass.drag || area.a.klass.vdrag || area.a.klass.hover));

        // Add helptips on navigation controls in multi species view
        if (area && area.a && (area.a.klass.nav || area.a.klass.tooltip)) {
          if (tip !== area.a.attrs.alt) {
            tip = area.a.attrs.alt;
            
            if (!panel.elLk.helpTip) {
              panel.elLk.helpTip = $('<div class="ui-tooltip helptip-top"><div class="ui-tooltip-content"></div></div>');
            }
            
            panel.elLk.helpTip.children().html(tip).end().appendTo('body').position({
              of: { pageX: panel.imgOffset.left + area.l + 10 , pageY: panel.imgOffset.top + area.b + (area.b -area.t) - 15, preventDefault: true }, // fake an event
              my: 'center top'
            });
          }
        } else {
          if (panel.elLk.helpTip) {
            panel.elLk.helpTip.detach().css({ top: 0, left: 0 });
          }
        }
      },
      mouseleave: function(e, e2) {

        e = e2 || e;

        if (e.relatedTarget) {

          if (panel.elLk.helpTip) {
            panel.elLk.helpTip.detach();
          }

        }
      },
      click: function (e, e2) {

        e = e2 || e;

        if (panel.clicking) {
          panel.makeZMenu(e, panel.getMapCoords(e));
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

        var share_url_input = hoverLabel.find('.hl-content ._copy_url');
        var share_url = ($('<a/>', {'href': share_url_input.val()})).prop('href');
        share_url_input.val(share_url);

        // Create an href from <a> and get a valid url
        hoverLabel.find('.hl-content ._copy_url').val(share_url);

        if (hoverLabel.length) {
          // add a div layer over the label, and append the hover menu to the layer. Hover menu toggling is controlled by CSS.
          panel.elLk.labelLayers = panel.elLk.labelLayers.add(
            $('<div class="label_layer _label_layer">')
            .append('<div class="label_layer_bg">')
            .append(hoverLabel)
            .appendTo(panel.elLk.container)
            .data({area: this})
          );
        }

        panel.labelWidth = Math.max(panel.labelWidth, this.a.coords[2]);

        hoverLabel = null;

      } else if (this.a.klass.hover) {

        panel.elLk.hoverLayers = panel.elLk.hoverLayers.add(
          $('<div class="hover_layer">').appendTo(panel.elLk.container).data({area: this}).on('mousedown mousemove click', function (e) {
            panel.elLk.drag.triggerHandler(e.type, e);
          })
        );
      } else if(this.a.klass.hoverzmenu && this.a.attrs.alt) { // hover simulates click

        var layer = $('<div class="label_layer">');
        layer.appendTo(panel.elLk.container).data({area: this});
        panel.elLk.labelLayers = panel.elLk.labelLayers.add(layer);

        (function(layer) {
          layer.on('click',function(e) {
            if (!$(this).data('zmenu')) {
              var zmid = panel.makeZMenu(e,panel.getMapCoords(e),{'approx':2});
              $(this).data('zmenu', zmid);
            }
            $('#' + $(this).data('zmenu')).show().find('.close').remove();
          });
          layer.on('mouseleave',function(e) {
            $('#' + $(this).data('zmenu')).delay(200).hide(0).on('mouseenter', function() {
              $(this).clearQueue();
            }).on('mouseleave', function() {
              $(this).hide();
            });
          });
        })(layer);
      }
      $a = null;
    });

    // add dyna loading to label layers for track description
    this.elLk.labelLayers.on ({
      mouseenter: function () {
        $(this).find('._dyna_load').removeClass('_dyna_load').dynaLoad();
        var associated_li = panel.elLk.boundaries.find('.' + $(this).find('.hl-icon-highlight').data('highlightTrack'))
        associated_li.addClass('hover');
      },
      mouseleave: function () {
        panel.elLk.boundaries.find('.' + $(this).find('.hl-icon-highlight').data('highlightTrack')).removeClass('hover');
      },
      click: function(e) {
        // Hide all open menus on clicking new menu except the pinned ones.
        $(this).siblings().not('.pinned').find('.hover_label').hide();
        // siblings() doesnt return the current clicked element
        // So check if the current element is pinned.
        if ($(this).hasClass('pinned')) {
          return;
        }
        // show/hide hover label
        $(this).find('.hover_label')
               .toggle().off()
               .click(function(e){
                  if (e.target.nodeName !== "A" || $(e.target).hasClass('config')) {
                    e.stopPropagation();
                  }
               });

       $(document).off('.hoverMenuRemove').on('click.hoverMenuRemove', function(e) {
          if ($(e.target).is('._label_layer')) {
            return;
          }
          $(panel.elLk.labelLayers).not('.pinned').find('.hover_label').hide();
          $(this).off('.hoverMenuRemove');
        });

      }
    })
    .find('.close')
      .on ({
        click: function(e) {
          $(this).parent().hide();
          // Remove pinned class
          $(this).siblings('._hl_pin').removeClass('on')
                 .closest('._label_layer').removeClass('pinned');
          e.stopPropagation(); // aviod triggering click on parent _label_layer
          $(document).off('.hoverMenuRemove');
        }
      }).externalLinks();


    // apply css positions to the hover layers
    this.positionLayers();

    // position hover menus to the right of the layer
    this.elLk.hoverLabels.css('left', function() { return $(this.parentNode).width(); });

    // initialise content inside hover labels
    this.initHoverLabels();
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
        left:   left + area.l + 1,
        top:    top + area.t + 1,
        height: area.b - area.t,
        width:  area.r - area.l
      });

      area = $this = null;
    });
  },

  initHoverLabels: function () {
    var panel = this;

    this.elLk.hoverLabels.each(function() {

      // init the tab styled icons inside the hover menus
      $(this).find('._hl_icon').removeClass('_hl_icon').tabs($(this).find('._hl_tab')).end()

      // init the header/pin icon that holds the hover label if clicked
      .find('._hl_pin').off().on('click', function (e) {
        $(this).toggleClass('on').closest('._label_layer').toggleClass('pinned', $(this).hasClass('on'));
        e.stopPropagation && e.stopPropagation();
      }).end()

      // init the extend icon to drag-change hover label's width
      .find('._hl_extend').off().on({
        click: function (e) {
          e.stopPropagation() // prevent click on the header/pin
        },
        mousedown: function (e) {
          e.preventDefault(); // this is to prevent any text selection when mouse moves
          var hoverLabel = $(this).closest('.hover_label');
          $(document).on('mousemove.resizeHoverLabel', { hoverLabel: hoverLabel, startX: e.pageX, startW: hoverLabel.width() }, function (e) {
            e.data.hoverLabel.css('width', Math.max(300, Math.min(Ensembl.cookie.get('ENSEMBL_WIDTH') - 300, e.data.startW + e.pageX - e.data.startX)));
          }).on('mouseup.resizeHoverLabel', function () {
            $(document).off('.resizeHoverLabel');
          });
        }
      });
    })
    // On highlight icon click toggle highlight
    .find('.hl-icon-highlight').on('click', function(e) {
      e.preventDefault();
      panel.toggleHighlight($(this).data('highlightTrack'));
    }).end()

    // init config tab, fav icon and close icon
    .find('a.config').on('click', function (e) {
      e.preventDefault();
      panel.handleConfigClick(this);
    }).end()

    // Ditto for graph y-axis form
    .find('form.graph_config').on('submit', function (e) {
      e.preventDefault();
      panel.handleGraphForm(this);
    }).end()

    // while url input is focused, don't hide the hover label
    .find('input._copy_url').off().on('click focus blur', function(e) {
      $(this).val(this.value).select().closest('._label_layer').toggleClass('focused', e.type !== 'blur');
    });
  },

  toggleHighlight: function(uniq_track_ids, _on) {
    var panel = this;

    if (!Array.isArray(uniq_track_ids)) {
      uniq_track_ids = [uniq_track_ids];
    }

    $.each(uniq_track_ids, function(i, tr) {
      track = tr && tr.split('.')[0];
      var track_element = $($(panel.elLk.boundaries).find('li.' + track));

      if (!track_element) {
        return;
      }

      if (_on) {
        $(track_element) && $(track_element).addClass('track_highlight');  
      }
      else {
        if (_on !== '' && _on !== undefined) {
          $(track_element) && $(track_element).removeClass('track_highlight');
        }
        else {
          $(track_element) && $(track_element).toggleClass('track_highlight');
        }
      }      
    });

    this.updateHighlightedTracks();
  },

  updateHighlightedTracks: function() {

    var panel = this;
    // Get tracks (which include strands)
    // e.g. track seq has 2 associated tracks - seq.f and seq.r
    $.each(panel.elLk.hoverLabels, function(i, tr) {
      var uniq_tr_id = $(tr).find('.hl-icon-highlight').data('highlightTrack');
      var li = $('li', panel.elLk.boundaries).filter('.track_highlight.' + uniq_tr_id);
      li.length ? panel.highlightedTracks[uniq_tr_id] = 1 : panel.highlightedTracks[uniq_tr_id] && delete panel.highlightedTracks[uniq_tr_id];
    });
    
    this.updateExportButton();
  },

  highlightLastUploadedUserDataTrack: function() {
    var panel = this;
    var tracks = [];

    this.elLk.boundaries.find('li._new_userdata.usertrack_highlight').on('mouseover', function() {
      panel.removeUserDataHighlight();
    })

    // Traverse li to find adjacent tracks to add group border
    var count = 0;
    this.elLk.boundaries.children().each(function (i) {
      var li  = $(this);
      if ($(this).hasClass('_new_userdata')) {
        tracks.push(li);
        count++;
      }
      else {
        // Reset array so that you get a new set of tracks
        panel.addHighlightClasses(tracks);
        tracks = [];
        count++;
      }
      // In case last li track is a _new_userdata (which misses the else part above)
      (tracks.length && panel.elLk.boundaries.children().length === count) && panel.addHighlightClasses(tracks)
    });

  },

  addHighlightClasses: function(tracks) {
    // If there are more than one tracks adjacent to each other
    if(tracks.length > 1) {
      $(tracks).each(function(i, li_element) {
        // Top track
        if (i == 0) {
          $(li_element).addClass('usertrack_highlight_border_top usertrack_highlight_border_left usertrack_highlight_border_right');
        }
        // Middle tracks
        else if (i !== tracks.length - 1 ) {
          $(li_element).addClass('usertrack_highlight_border_left usertrack_highlight_border_right');
        }
        // Bottom track
        else {
          $(li_element).addClass('usertrack_highlight_border_bottom usertrack_highlight_border_left usertrack_highlight_border_right');
        }
      })
    }
    else {
      // Single tracks
      tracks.length == 1 &&
        $(tracks[0]).addClass('usertrack_highlight_border_top usertrack_highlight_border_bottom usertrack_highlight_border_left usertrack_highlight_border_right');
    }

  },

  removeUserDataHighlight: function() {
    $(this.elLk.boundaries).find('._new_userdata').removeClass('usertrack_highlight _new_userdata usertrack_highlight_border_top usertrack_highlight_border_left usertrack_highlight_border_right usertrack_highlight_border_bottom');
  },

  handleConfigClick: function (link) {
    var $link = $(link);

    if ($link.parent().hasClass('current')) {
      return;
    }

    var config  = link.rel;
    var href    = link.href.split(';');
    var update  = href.pop().split('='); // update = [ trackId, renderer ]

    var selected     = '';
    var imgConf = {};
    var hasFav = $link.hasClass('favourite');
    var hasHighlight = $link.hasClass('hl-icon-highlight');
    var isMatrix = $link.hasClass('matrix-cell');

    if (hasFav || hasHighlight) {
      selected = $link.hasClass('selected') ? 'off' : 'on';
      href.push(update[0] + '=' + update[1] + selected);
      hasFav && Ensembl.EventManager.trigger('changeFavourite', update[0], selected === 'on');
      this.changeHighlightTrackIcon(update[0], selected === 'on');
    } else {
      $link.parents('._label_layer').addClass('hover_label_spinner');
      imgConf[update[0]] = {'renderer' : update[1]};
      href.push('image_config=' + encodeURIComponent(JSON.stringify(imgConf)));
    }

    $.ajax({
      url: href.join(';'),
      dataType: 'json',
      context: { panel: this, track: update[0], update: update[1] },
      success: function (json) {
        if (json.updated) {
          this.panel.changeConfiguration(config, this.track, this.update);
          this.panel.updateExportButton();
          // Also update matrix if appropriate
          if (isMatrix) {
            Ensembl.EventManager.trigger('updateFromTrackLabel', update);
          }
        }
      }
    });

    $link = null;
  },

  handleGraphForm: function (form) {
    // Update track config y-axis values from popup form
    var form      = $(form);
    var action    = form.prop('action');
    var href      = action.split(';');
    var conf      = form.find('input[name=config]').val();
    var trackName = form.find('input[name=track]').val();
    var yMin      = form.find('input[name=y_min]').val();
    var yMax      = form.find('input[name=y_max]').val();
    
    form.parents('._label_layer').addClass('hover_label_spinner');
    var imgConf = {};
    imgConf[trackName] = {'y_max' : yMax, 'y_min' : yMin};
    href.push('image_config=' + encodeURIComponent(JSON.stringify(imgConf)));

    $.ajax({
      url: href.join(';'),
      dataType: 'json',
      context: { panel: this, track: trackName, update: yMax },
      success: function (json) {
        if (json.updated) {
          this.panel.changeAxes(conf, this.track, this.y_min, this.y_max);
          //this.panel.updateExportButton();
        }
      }
    });

    $form = null;
  },

  changeConfiguration: function (config, trackName, renderer) {
    Ensembl.EventManager.triggerSpecific('changeConfiguration', 'modal_config_' + config, trackName, renderer);

    if (renderer === 'off') {
      if (this.removeTrack(trackName)) {
        return;
      }
    }

    Ensembl.EventManager.trigger('reloadPage', this.id);
    Ensembl.EventManager.trigger('partialReload');
  },
 
  changeAxes: function (config, trackName, yMin, yMax) {
    Ensembl.EventManager.triggerSpecific('changeAxes', 'modal_config_' + config, trackName, yMin, yMax);

    Ensembl.EventManager.trigger('reloadPage', this.id);
    Ensembl.EventManager.trigger('partialReload');
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
            this.assigned = true;
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
    }).css('visibility', 'visible');

    // split img into two image to show top and bottom of the image separately
    this.elLk.img2 = this.elLk.img.wrap('<div>').parent().css({overflow: 'hidden', height: wrapperTop}).clone().insertAfter(this.elLk.img.parent()).css({height: 'auto'}).find('img').css({marginTop: -wrapperTop});
  },

  removeTrack: function (trackName) {
    var panel = this;

    if (!this.elLk.img2) {
      return false;
    }

    //remove track and areas and get the height of the removed tracks
    var heightChange = 0;
    this.el.find('li.' + trackName).each(function() {
      var li    = $(this);
      var areas = li.data('areas');

      panel.areas = $.grep(panel.areas, function (a) {
        return $.inArray(a, areas) === -1;
      });

      heightChange += parseInt(li.css('height'));
      li = null;

    }).remove();

    // remove hover labels
    this.elLk.labelLayers = this.elLk.labelLayers.has('.' + trackName).remove().end().filter(function() { return !!this.parentNode; });

    // now reduce the height of the img to make sure the LIs still completely overlap the img
    this.elLk.img2.css('marginTop', parseInt(this.elLk.img2.css('marginTop')) - heightChange);

    this.positionAreas(-heightChange);
    this.positionLayers();
    this.removeShare();
    Ensembl.EventManager.trigger('removeShare')

    Object.keys(this.highlightRegions).length > 0 && this.highlightImage(this.imageNumber, 0);
    this.markLocation(Ensembl.markedLocation);

    return true;
  },

  sortStart: function (e, ui) {
    // make the placeholder similar to the actual track but slightly faded so the saturated background colour beneath gives it a highlighted effect
    ui.placeholder.css({
      backgroundImage:     ui.item.css('backgroundImage'),
      backgroundPosition:  ui.item.css('backgroundPosition'),  // Firefox
      backgroundPositionY: ui.item.css('backgroundPositionY'), // IE (Chrome works with either)
      height:              ui.item.height(),
      opacity:             0.8
    }).html(ui.item.html());

    // add some transparency to the helper (already a clone of actual track) that moves with the mouse
    ui.helper.stop().css({opacity: 0.8}).addClass('helper');

    // css deals with the rest of the things
    $(document.body).addClass('track-reordering');

    this.dragging = true;
  },

  sortStop: function (e, ui) {
    $(document.body).removeClass('track-reordering');
    this.dragging = false;
  },

  sortUpdate: function(e, ui) {

    var prev  = $.trim((ui.item.prev().prop('className') || '')).replace(' ', '.');
    var track = $.trim(ui.item.prop('className')).replace(' ', '.');

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

  positionAreas: function (change) {
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

    if (change) {
      $.each(this.areas, function (i, area) {
        if (area.a.klass.drag) {
          area.b += change;
        } else if (area.a.klass.label && !area.assigned) {
          area.t += change;
          area.b += change;
        }
      });
    }

    tracks = null;
  },

  changeFavourite: function (trackId, on) {
    this.elLk.hoverLabels.filter('.' + trackId).find('a.favourite').toggleClass('selected', on);
  },

  changeHighlightTrackIcon: function (trackId, on) {
    var panel = this;
    panel.elLk.hoverLabels.filter('.' + trackId).find('a.hl-icon-highlight').toggleClass('selected', on);
  },

  dragStart: function (e) {
    var panel = this;
    
    this.dragCoords.map    = this.getMapCoords(e);
    this.dragCoords.page   = { x: e.pageX, y : e.pageY };
    this.dragCoords.offset = { x: e.pageX - this.dragCoords.map.x, y: e.pageY - this.dragCoords.map.y }; // Have to use this instead of the map coords because IE can't cope with offsetX/Y and relative positioned elements
    
    this.dragRegion = this.getArea(this.dragCoords.map, true);
    
    if (this.dragRegion) {
      this.mousemove = function (e1, e2) {
        panel.dragging = e; // store mousedown event
        panel.drag(e2 || e1);
        return false;
      };
      
      this.elLk.drag.on('mousemove', this.mousemove);

      $(document).on('keyup.exitOnEsc', function(e) {
        if (e.which === 27) { // Escape key
          panel.newLocation = false;
          if (panel.panning) {
            panel.dragStop();
          }
        }
      });

      this.altKeyDragging = e.altKey || e.shiftKey || e.metaKey;

      if (this.altKeyDragging) {
        this.setPanning(!this.panning);
      }

      if (this.panning) {
        this.selectArea(false);
        this.removeZMenus();
        this.elLk.hoverLayers.hide();
      }
    }
  },
  
  dragStop: function (e) {
    var diff, range;
    
    if (this.mousemove) {
      this.elLk.drag.off('mousemove', this.mousemove);
      this.mousemove = false;

      $(document).off('.exitOnEsc');

      if (this.altKeyDragging) {
        this.setPanning(!this.panning);
      }
    }
    
    if (this.dragging !== false) {

      this.elLk.hoverLayers.show();

      if (this.elLk.boundariesPanning) {

        this.dragging = false;
        this.clicking = false;

        this.elLk.boundariesPanning.helptip('destroy');

        if (!this.newLocation) {
          this.elLk.boundariesPanning.parent().remove();
          this.elLk.boundariesPanning = false;
          this.markLocation(Ensembl.markedLocation);
          return;
        }

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

  setPanning: function (flag) {
    if (this.panningAllowed) {
      if (typeof flag === 'undefined') {
        flag = Ensembl.cookie.get('ENSEMBL_REGION_PAN') === '1';
      } else {
        Ensembl.cookie.set('ENSEMBL_REGION_PAN', flag ? '1' : '0');
      }

      this.panning = flag;
      this.elLk.dragSwitch.toggleClass2('selected', function() {
        return $(this).find('button').hasClass('on') ? flag : !flag;
      });
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
      this.markLocation(Ensembl.markedLocation, locationDisplacement);
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
    var area;
    if(coords.r) {
      area = this.dragRegion;
    } else if(params && params.approx) {
      area = this.getBestArea(coords,undefined,params.approx);
    } else {
      area = this.getArea(coords);
    }

    if (!area || area.a.klass.label || area.a.klass.tooltip) {
      return;
    }
    
    if (area.a.klass.nav) {
      this.navClick(area, e);
      return;
    }

    if (area.a.attrs.href && Ensembl.markedLocation) {
      area.a.attrs.href = Ensembl.updateURL({mr: Ensembl.markedLocation[0]}, area.a.attrs.href);
    }

    var id = (params && params.mr_menu ? 'mr_menu' : 'zmenu_') + area.a.coords.join('_');
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

        coords.clickY     = area.a.coords[3] - coords.y;
        
        id += '_multi';
      }
      
      dragArea = null;
    }

    if(params && params.close) {
      var zmenu = $('#'+id);
      if(zmenu)
        zmenu.hide();
      return;
    }

    Ensembl.EventManager.trigger('makeZMenu', id, $.extend({ event: e, coords: coords, area: area, imageId: this.id, relatedEl: area.a.id ? $('.' + area.a.id, this.el) : false }, params));
    this.zMenus[id] = 1;
    return id;
  },

  navClick: function(area, e) {
    Ensembl.redirect(area.a.attrs.href);
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
        t: Math.round(highlight.region.t + 2),
        b: Math.round(highlight.region.b - 2),
        l: Math.round(((start - highlight.region.range.start) / highlight.region.range.scale) + highlight.region.l),
        r: Math.round(((end   - highlight.region.range.start) / highlight.region.range.scale) + highlight.region.l)
      };

      // Highlight unless it's the bottom image on the page
      if (this.params.highlight) {
        this.boxCoords[speciesNumber] = coords;
        this.updateExportButton();
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

    this.selectArea(false);
    
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

    this.elLk.selector.css({ left: coords.l, top: coords.t, width: coords.r - coords.l + 1, height: coords.b - coords.t - 1 }).show();
  },

  initSelector: function () {
    if (!this.elLk.selector || !this.elLk.selector.length) {
      this.elLk.selector = $('<div class="_selector selector"></div>').insertAfter(this.elLk.img).toggleClass('vertical', this.vertical).filter(':not(.vertical)')
        .append('<div class="left-border"></div><div class="right-border"></div>').end();
      this.activateSelector();
    }
  },

  activateSelector: function() {
    this.elLk.selector.on('click', function(e) {
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

        if (e.data.action !== 'right') {
          disp = Math.max(disp, e.data.panel.dragRegion.l + 1 - coords.left);
        }
        if (e.data.action !== 'left') {
          disp = Math.min(e.data.panel.dragRegion.r - coords.left - coords.width + 1, disp);
        }

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
  },

  markLocation: function (r, offset) {
    var panel = this;
    var start, end;

    offset = offset || 0;

    // not for vertical or multi species images
    if (this.vertical || this.multi) {
      return;
    }

    // if image box is not interactive
    if (!this.locationMarkingArea) {
      return;
    }
    // create the marked area div
    if (!this.elLk.markedLocation) {
      this.elLk.markedLocation = $('<div class="selector mrselector"><div class="mrselector-close">&#9776;</div></div>').hide().insertAfter(this.elLk.selector)
        .find('div').helptip({content: 'Click for more options'}).on('click mousedown', function(e) {
          e.stopPropagation();
          $(this).helptip('close');
          if (e.type === 'click') {
            panel.makeZMenu(e, panel.getMapCoords(e), { onclose: function() { panel.selectArea(false); }, context: panel, mr_menu : 1 });
          }
        })
      .end();
    }

    // create the marker button
    if (!this.elLk.markerButton) {
      this.elLk.markerButton = $('<a class="mr-reset outside">').hide().appendTo(this.elLk.toolbars).helptip().on({
        'refreshTip': function () {
          $(this).helptip('option', 'content', this.className.match(/outside/) ? 'Jump to the marked region' : (this.className.match(/selected/) ? 'Clear marked region' : 'Reinstate marked region'))
        },
        'click': function (e) {
          e.preventDefault();
          if (this.className.match('selected')) {
            Ensembl.markLocation(false);
          } else if (this.className.match(/outside/)) {
            var mr      = Ensembl.getMarkedLocation() || Ensembl.lastMarkedLocation;
            var length  = panel.locationMarkingArea.range.end - panel.locationMarkingArea.range.start; // preserve the scale
            var centre  = (mr[2] + mr[3]) / 2;
            Ensembl.markLocation(mr);
            Ensembl.updateLocation(mr[1] + ':' + Math.max(1, Math.round(centre - length / 2)) + '-' + Math.round(centre + length / 2));
          } else {
            Ensembl.markLocation(Ensembl.lastMarkedLocation);
          }
        }
      });
    }

    // if clearing the marked area
    if (r === false) {
      this.elLk.markedLocation.hide();
      this.elLk.markerButton.removeClass('selected').trigger('refreshTip').show();
      this.updateExportButton();
      return;
    }

    // if r is null or undefined - no param in the url
    if (!r) {
      return;
    }

    // remove image selector if any
    this.selectArea(false);

    // calculate start and end of the current image
    start = this.locationMarkingArea.range.start - offset;
    end   = (this.locationMarkingArea.range.end+1) - offset;

    // display the marked region if it overlaps the current region
    if (this.locationMarkingArea.range.chr === r[1] && (start > r[2] && start < r[3] || end > r[2] && end < r[3] || start <= r[2] && end >= r[3])) {

      this.elLk.markedLocation.css({
        left:   this.locationMarkingArea.l + Math.max(r[2] - start, 0) / this.locationMarkingArea.range.scale,
        width:  (Math.min(end, r[3] + 1) - Math.max(r[2], start)) / this.locationMarkingArea.range.scale - 1,
        top:    this.locationMarkingArea.t,
        height: this.locationMarkingArea.b - this.locationMarkingArea.t
      }).show();

      this.elLk.markerButton.addClass('selected').removeClass('outside').trigger('refreshTip').show();

    } else {
      this.elLk.markedLocation.hide();
      if (this.panningAllowed) {
        this.elLk.markerButton.addClass('outside').removeClass('selected').trigger('refreshTip').show();
      } else {
        this.elLk.markerButton.hide();
      }
    }

    this.updateExportButton();
  },

  updateExportButton: function() {
    var extra = this.getExtraExportParam();

    extra = $.isEmptyObject(extra) ? false : encodeURIComponent(JSON.stringify(extra));

    this.elLk.exportButton.attr('href', function() {
      return Ensembl.updateURL({extra: extra, decodeURL: 1}, this.href);
    });
  },

  getExtraExportParam: function () {
    var extra = {};

    var flag = 0;
    extra.highlightedTracks = Object.keys(this.highlightedTracks);

    if (!$.isEmptyObject(this.boxCoords)) {
      extra.boxes = this.boxCoords;
    }

    if (Ensembl.markedLocation && this.locationMarkingArea) {
      extra.mark = {
        x: Math.round((Ensembl.markedLocation[2] - this.locationMarkingArea.range.start) / this.locationMarkingArea.range.scale + this.locationMarkingArea.l),
        y: this.locationMarkingArea.t,
        w: Math.round((Ensembl.markedLocation[3] - Ensembl.markedLocation[2]) / this.locationMarkingArea.range.scale),
        h: this.locationMarkingArea.b - this.locationMarkingArea.t
      };

      if (extra.mark.x < this.locationMarkingArea.l) {
        extra.mark.w = extra.mark.w - this.locationMarkingArea.l + extra.mark.x;
        extra.mark.x = this.locationMarkingArea.l;
      }

      if (extra.mark.w <= 0) {
        delete extra.mark;
      }
    }
    return extra;
  },

  getMapCoords: function (e) {
    if (this.elLk.img || this.imgOffset) {
      this.imgOffset = this.imgOffset || this.elLk.img.offset();
    }
    else {
      this.imgOffset = 0;
    }
    return {
      x: e.pageX - this.imgOffset.left - 1, // exclude the 1px borders
      y: e.pageY - this.imgOffset.top - 1
    };
  },

  getBestArea: function(coords,draggables,delta) {
    var i,w = [[0,0],[-1,0],[1,0],[0,-1],[0,1]];

    for(var i=0;i<w.length;i++) {
      var x = coords.x + w[i][0]*delta;
      var y = coords.y + w[i][1]*delta;
      var v = this.getArea({ 'x': x, 'y': y },draggables);
      if(v) {
        return v;
      }
    }
  },

  getArea: function (coords, draggables) {
    var test  = false;
    var areas = draggables ? this.draggables : this.areas;
    var c;
    var last;
    var current;

    for (var i = 0; i < areas.length; i++) {
      c = areas[i];

      switch (c.a.shape.toLowerCase()) {
        case 'circle': test = this.inCircle(c.c, coords); break;
        case 'poly':   test = this.inPoly(c.c, coords); break;
        default:       test = this.inRect(c, coords); break;
      }

      if (test === true) {
        current = $.extend({}, c);

        // if the areas are overlapping (in case of transparent areas, return the one drawn on top)
        if (!current.a.attrs.overlap) {
          return last || current;
        }

        last = current;
      }
    }

    return last;
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
