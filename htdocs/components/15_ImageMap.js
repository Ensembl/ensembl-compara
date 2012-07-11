// $Revision$

Ensembl.Panel.ImageMap = Ensembl.Panel.Content.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    this.dragging         = false;
    this.clicking         = true;
    this.dragCoords       = {};
    this.dragRegion       = {};
    this.highlightRegions = {};
    this.areas            = [];
    this.draggables       = [];
    this.speciesCount     = 0;
    
    function resetOffset() {
      delete this.imgOffset;
    }
    
    Ensembl.EventManager.register('highlightImage',     this, this.highlightImage);
    Ensembl.EventManager.register('mouseUp',            this, this.dragStop);
    Ensembl.EventManager.register('hashChange',         this, this.hashChange);
    Ensembl.EventManager.register('changeFavourite',    this, this.changeFavourite);
    Ensembl.EventManager.register('imageResize',        this, function () { if (this.xhr) { this.xhr.abort(); } this.getContent(); });
    Ensembl.EventManager.register('windowResize',       this, resetOffset);
    Ensembl.EventManager.register('ajaxLoaded',         this, resetOffset); // Adding content could cause scrollbars to appear, changing the offset, but this does not fire the window resize event
    Ensembl.EventManager.register('changeWidth',        this, function () { Ensembl.EventManager.trigger('queuePageReload', this.id); });
    Ensembl.EventManager.register('highlightAllImages', this, function () { if (!this.align) { this.highlightAllImages(); } });
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    this.imageConfig      = $('input.image_config', this.el).val();
    this.lastImage        = this.el.parents('.image_panel')[0] === Ensembl.images.last;
    this.hashChangeReload = this.lastImage || $('.hash_change_reload', this.el).length;
    
    this.params.highlight = (Ensembl.images.total === 1 || !this.lastImage);
    
    this.elLk.drag        = $('.drag_select',  this.el);
    this.elLk.map         = $('map',           this.el);
    this.elLk.areas       = $('area',          this.elLk.map);
    this.elLk.exportMenu  = $('.iexport_menu', this.el);
    this.elLk.img         = $('img.imagemap',  this.el);
    this.elLk.hoverLabels = $('.hover_label',  this.el);
    this.elLk.boundaries  = $('.boundaries',   this.el);
    
    this.vdrag = this.elLk.areas.hasClass('vdrag');
    this.multi = this.elLk.areas.hasClass('multi');
    this.align = this.elLk.areas.hasClass('align');
    
    this.makeImageMap(); 
    this.makeHoverLabels(); 
    
    if (this.elLk.boundaries.length) {
      Ensembl.EventManager.register('changeTrackOrder', this, this.sortUpdate);
      
      if (this.elLk.img[0].complete) {
        panel.makeSortable();
      } else {
        this.elLk.img.on('load', function () { panel.makeSortable(); });
      }
    }
    
    if (typeof FileReader !== 'undefined') {
      this.dropFileUpload();
    }
    
    panel.elLk.exportMenu.appendTo('body').css('left', this.el.offset().left);
    
    $('a.iexport', this.el).on('click', function () {
      panel.elLk.exportMenu.css({ top: $(this).parent().hasClass('bottom') ? $(this).parent().offset().top - panel.elLk.exportMenu.outerHeight() : panel.elLk.img.offset().top }).toggle();
      return false;
    });
  },
  
  hashChange: function (r) {
    this.params.updateURL = Ensembl.urlFromHash(this.params.updateURL);
    
    if (this.hashChangeReload) {
      this.base();
    } else if (Ensembl.images.total === 1) {
      this.highlightAllImages();
    } else if (!this.multi) {
      var range = this.highlightRegions[0][0].region.range;
      r = r.split(/\W/);
      
      if (parseInt(r[1], 10) < range.start || parseInt(r[2], 10) > range.end || this.highlightRegions[0][0].region.a.href.split('|')[4] !== r[0]) {
        this.base();
      }
    }
    
    if (this.align) {
      Ensembl.EventManager.trigger('highlightAllImages');
    }
  },
  
  makeImageMap: function () {
    var panel = this;
    
    var highlight = !!(window.location.pathname.match(/\/Location\//) && !this.vdrag);
    var rect      = [ 'l', 't', 'r', 'b' ];
    var speciesNumber, c, r, start, end, scale;
    
    this.elLk.areas.each(function () {
      c = { a: this };
      
      if (this.shape && this.shape.toLowerCase() !== 'rect') {
        c.c = [];
        $.each(this.coords.split(/[ ,]/), function () { c.c.push(parseInt(this, 10)); });
      } else {
        $.each(this.coords.split(/[ ,]/), function (i) { c[rect[i]] = parseInt(this, 10); });
      }
      
      panel.areas.push(c);
      
      if (this.className.match(/drag/)) {
        // r = [ '#drag', image number, species number, species name, region, start, end, strand ]
        r     = c.a.href.split('|');
        start = parseInt(r[5], 10);
        end   = parseInt(r[6], 10);
        scale = (end - start + 1) / (c.r - c.l); // bps per pixel on image
        
        c.range = { start: start, end: end, scale: scale };
        
        panel.draggables.push(c);
        
        if (highlight === true) {
          r = this.href.split('|');
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
        // Only draw the drag box for left clicks.
        // This property exists in all our supported browsers, and browsers without it will draw the box for all clicks
        if (!e.which || e.which === 1) {
          panel.dragStart(e);
        }
        
        return false;
      },
      click: function (e) {
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
    
    this.elLk.hoverLabels.detach().appendTo('body'); // IE 6/7 can't do z-index, so move hover labels to body
    
    this.elLk.drag.on({
      mousemove: function (e) {
        if (panel.dragging !== false) {
          return;
        }
        
        var area  = panel.getArea(panel.getMapCoords(e));
        var hover = false;
        
        if (area && area.a) {
          if ($(area.a).hasClass('label')) {
            var label = panel.elLk.hoverLabels.filter('.' + area.a.className.replace(/label /, ''));
            
            if (!label.hasClass('active')) {
              panel.elLk.hoverLabels.filter('.active').removeClass('active');
              label.addClass('active');
              
              clearTimeout(panel.hoverTimeout);
              
              panel.hoverTimeout = setTimeout(function () {
                var offset = panel.elLk.img.offset();
                
                panel.elLk.hoverLabels.filter(':visible').hide().end().filter('.active').css({
                  left:    area.l + offset.left,
                  top:     area.t + offset.top,
                  display: 'block'
                });
              }, 100);
            }
            
            hover = true;
          } else if ($(area.a).hasClass('nav')) { // Used to title tags on navigation controls in multi species view
            panel.elLk.img.attr('title', area.a.alt);
          }
        }
        
        if (hover === false) {
          clearTimeout(panel.hoverTimeout);
          panel.elLk.hoverLabels.filter('.active').removeClass('active');
        }
      },
      mouseleave: function (e) {
        if (e.relatedTarget) {
          var active = panel.elLk.hoverLabels.filter('.active');
          
          if (!active.has(e.relatedTarget).length) {
            active.removeClass('active').hide();
          }
          
          active = null;
        }
      }
    });
    
    this.elLk.hoverLabels.on('mouseleave', function () {
      $(this).hide().children('div').hide();
    });
    
    this.elLk.hoverLabels.children('img').hoverIntent(
      function () {
        var width = $(this).parent().outerWidth();
        
        $(this).siblings('div').hide().filter('.' + this.className.replace(/ /g, '.')).show().width(function (i, value) {
          return value > width && value > 300 ? 300 : value;
        });
      },
      $.noop
    );
    
    $('a.config', this.elLk.hoverLabels).on('click', function () {
      var config = this.rel;
      var update = this.href.split(';').reverse()[0].split('='); // update = [ trackName, renderer ]
      var fav    = '';
      
      if ($(this).hasClass('favourite')) {
        fav = $(this).hasClass('selected') ? 'off' : 'on';
        Ensembl.EventManager.trigger('changeFavourite', update[0], fav === 'on');
      } else {
        $(this).parents('.hover_label').width(function (i, value) {
          return value > 100 ? value : 100;
        }).find('.spinner').show().siblings('div').hide();
      }
      
      $.ajax({
        url: this.href + fav,
        dataType: 'json',
        success: function (json) {
          if (json.updated) {
            panel.elLk.hoverLabels.remove(); // Deletes elements moved to body
            Ensembl.EventManager.trigger('hideHoverLabels'); // Hide labels and z menus on other ImageMap panels
            Ensembl.EventManager.trigger('hideZMenu');
            Ensembl.EventManager.triggerSpecific('changeConfiguration', 'modal_config_' + config, update[0], update[1]);
            Ensembl.EventManager.trigger('reloadPage', panel.id);
          }
        }
      });
      
      return false;
    });
    
    Ensembl.EventManager.register('hideHoverLabels', this, function () { this.elLk.hoverLabels.hide(); });
  },
  
  makeSortable: function () {
    var panel      = this;
    var wrapperTop = $('.boundaries_wrapper', this.el).position().top;
    var ulTop      = this.elLk.boundaries.position().top + wrapperTop - ($('body').hasClass('ie7') ? 3 : 0); // IE7 reports li.position().top as 3 pixels higher than other browsers, so offset that here.
    var lis        = [];
    
    this.dragCursor = $('body').hasClass('mac') ? 'move' : 'n-resize';
    
    this.elLk.boundaries.children().each(function (i) {
      var li = $(this);
      var t  = li.position().top + ulTop;
      
      li.data({ areas: [], position: i, order: parseFloat(li.children('i')[0].className, 10), top: li.offset().top });
      
      lis.push({ top: t, bottom: t + li.height(), areas: li.data('areas') });
      
      li = null;
    });
    
    $.each(this.areas, function () {
      var i = lis.length;
      
      while (i--) {
        if (lis[i].top <= this.t && lis[i].bottom >= this.b) {
          lis[i].areas.push(this);
          break;
        }
      }
    });
    
    this.elLk.boundaries.each(function () {
      $(this).data('updateURL', '/' + this.className.split(' ')[0] + '/Ajax/track_order');
    }).sortable({
      axis:   'y',
      handle: 'p.handle',
      helper: 'clone',
      placeholder: 'tmp',
      start: function (e, ui) {
        ui.placeholder.css({
          backgroundImage:     ui.item.css('backgroundImage'),
          backgroundPosition:  ui.item.css('backgroundPosition'),  // Firefox
          backgroundPositionY: ui.item.css('backgroundPositionY'), // IE (Chrome works with either)
          height:              ui.item.height(),
          opacity:             0.8,
          visibility:          'visible'
        }).html(ui.item.html());
        
        ui.helper.hide();
        $(this).find(':not(.tmp) p.handle').addClass('nohover');
        panel.elLk.drag.css('cursor', panel.dragCursor);
        panel.dragging = true;
      },
      stop: function () {
        $(this).find('p.nohover').removeClass('nohover');
        panel.elLk.drag.css('cursor', 'pointer');
        panel.dragging = false;
      },
      update: function (e, ui) {
        var order = panel.sortUpdate(ui.item);
        var track = ui.item[0].className.replace(' ', '.');
        
        $.ajax({
          url: $(this).data('updateURL'),
          type: 'post',
          data: {
            image_config: panel.imageConfig,
            track: track,
            order: order
          }
        });
        
        Ensembl.EventManager.triggerSpecific('changeTrackOrder', 'modal_config_' + panel.id.toLowerCase(), track, order);
      }
    }).css('visibility', 'visible');
  },
  
  sortUpdate: function (track, order) {
    var tracks = this.elLk.boundaries.children();
    var i, p, n, o, move, li, top;
    
    if (typeof track === 'string') {
      i     = tracks.length;
      track = tracks.filter('.' + track).detach();
      
      if (!track.length) {
        return;
      }
      
      while (i--) {
        if ($(tracks[i]).data('order') < order && tracks[i] !== track[0]) {
          track.insertAfter(tracks[i]);
          break;
        }
      }
      
      if (i === -1) {
        track.insertBefore(tracks[0]);
      }
      
      tracks = this.elLk.boundaries.children();
    } else {
      p = track.prev().data('order') || 0;
      n = track.next().data('order') || 0;
      o = p || n;
      
      if (Math.floor(n) === Math.floor(p)) {
        order = p + (n - p) / 2;
      } else {
        order = o + (p ? 1 : -1) * (Math.round(o) - o || 1) / 2;
      }
    }
    
    track.data('order', order);
    
    tracks.each(function (j) {
      li = $(this);
      
      if (j !== li.data('position')) {
        top  = li.offset().top;
        move = top - li.data('top'); // Up is positive, down is negative
        
        $.each(li.data('areas'), function () {
          this.t += move;
          this.b += move;
        });
        
        li.data({ top: top, position: j });
      }
      
      li = null;
    });
    
    tracks = track = null;
    
    return order;
  },
  
  changeFavourite: function (trackName) {
    this.elLk.hoverLabels.filter(function () { return this.className.match(trackName); }).children('a.favourite').toggleClass('selected');
  },
  
  dragStart: function (e) {
    var panel = this;
    
    this.dragCoords.map    = this.getMapCoords(e);
    this.dragCoords.page   = { x: e.pageX, y : e.pageY };
    this.dragCoords.offset = { x: e.pageX - this.dragCoords.map.x, y: e.pageY - this.dragCoords.map.y }; // Have to use this instead of the map coords because IE can't cope with offsetX/Y and relative positioned elements
    
    this.dragRegion = this.getArea(this.dragCoords.map, true);
    
    if (this.dragRegion) {
      this.mousemove = function (e2) {
        panel.dragging = e; // store mousedown even
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
      diff = { 
        x: e.pageX - this.dragCoords.page.x, 
        y: e.pageY - this.dragCoords.page.y
      };
      
      // Set a limit below which we consider the event to be a click rather than a drag
      if (Math.abs(diff.x) < 3 && Math.abs(diff.y) < 3) {
        this.clicking = true; // Chrome fires mousemove even when there has been no movement, so catch clicks here
      } else {
        range = this.vdrag ? { r: diff.y, s: this.dragCoords.map.y } : { r: diff.x, s: this.dragCoords.map.x };
        
        this.makeZMenu(e, range);
        
        this.dragging = false;
        this.clicking = false;
      }
    }
  },
  
  drag: function (e) {
    var x      = e.pageX - this.dragCoords.offset.x;
    var y      = e.pageY - this.dragCoords.offset.y;
    var coords = {};
    
    switch (x < this.dragCoords.map.x) {
      case true:  coords.l = x; coords.r = this.dragCoords.map.x; break;
      case false: coords.r = x; coords.l = this.dragCoords.map.x; break;
    }
    
    switch (y < this.dragCoords.map.y) {
      case true:  coords.t = y; coords.b = this.dragCoords.map.y; break;
      case false: coords.b = y; coords.t = this.dragCoords.map.y; break;
    }
    
    if (x < this.dragRegion.l) {
      coords.l = this.dragRegion.l;
    } else if (x > this.dragRegion.r) {
      coords.r = this.dragRegion.r;
    }
    
    if (y < this.dragRegion.t) {
      coords.t = this.dragRegion.t;
    } else if (y > this.dragRegion.b) {
      coords.b = this.dragRegion.b;
    }
    
    this.highlight(coords, 'rubberband', this.dragRegion.a.href.split('|')[3]);
  },
  
  makeZMenu: function (e, coords) {
    var area = coords.r ? this.dragRegion : this.getArea(coords);
    
    if (!area || $(area.a).hasClass('label')) {
      return;
    }
    
    if ($(area.a).hasClass('nav')) {
      Ensembl.redirect(area.a.href);
      return;
    }
    
    var id            = 'zmenu_' + area.a.coords.replace(/[ ,]/g, '_');
    var speciesNumber = 0;
    var dragArea, range, location, fuzziness;
    
    if (($(area.a).hasClass('das') || $(area.a).hasClass('group')) && this.highlightRegions) {
      if (this.speciesCount > 1) {
        dragArea = this.getArea(coords, true);
        
        if (dragArea) {
          speciesNumber = parseInt(dragArea.a.href.split('|')[1], 10) - 1;
        }
        
        dragArea = null;
      }
      
      range = this.draggables[speciesNumber] ? this.draggables[speciesNumber].range : undefined;
      
      if (range) {        
        location  = range.start + (range.scale * (coords.x - this.dragRegion.l));
        fuzziness = range.scale * 2; // Increase the size of the click so we can have some measure of certainty for returning the right menu
        
        coords.clickStart = Math.floor(location - fuzziness);
        coords.clickEnd   = Math.ceil(location + fuzziness);
        
        if (coords.clickStart < range.start) {
          coords.clickStart = range.start;
        }
        
        if (coords.clickEnd > range.end) {
          coords.clickEnd = range.end;
        }
      }
    }
    
    Ensembl.EventManager.trigger('makeZMenu', id, { position: { left: e.pageX, top: e.pageY }, coords: coords, area: area, imageId: this.id, relatedEl: area.a.id ? $('.' + area.a.id, this.el) : false });
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
    if (!this.draggables.length || this.vdrag || imageNumber - this.imageNumber > 1 || imageNumber - this.imageNumber < 0) {
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
  
  getMapCoords: function (e) {
    this.imgOffset = this.imgOffset || this.elLk.img.offset();
    
    return {
      x: e.pageX - this.imgOffset.left, 
      y: e.pageY - this.imgOffset.top
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
