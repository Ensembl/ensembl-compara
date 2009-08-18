// $Revision$

Ensembl.Panel.ImageMap = Ensembl.Panel.Content.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    this.dragging = false;
    this.clicking = true;
    this.dragCoords = {};
    
    this.dragRegion = {};
    this.highlightRegions = {};
    this.areas = []; // TODO: do we need both areas and draggables?
    this.draggables = [];
    this.speciesCount = 0;
    
    Ensembl.EventManager.register('highlightImage', this, this.highlightImage);
    Ensembl.EventManager.register('dragStop', this, this.dragStop);
  },
  
  init: function () {
    var myself = this;
    
    this.base();
    
    this.elLk.map = $('map', this.el);
    this.elLk.img = $('img.imagemap', this.el);
    this.elLk.areas = $('area', this.elLk.map);
    this.elLk.exportMenu = $('.iexport_menu', this.el);
    
    this.vdrag = this.elLk.areas.hasClass('vdrag');
    this.multi = this.elLk.areas.hasClass('multi');
    
    this.makeImageMap(); 
    
    $('.iexport a', this.el).click(function () {
      myself.elLk.exportMenu.css({ left: $(this).offset().left }).toggle();

      return false;
    });
  },
  
  makeImageMap: function () {
    var myself = this;
    
    var highlight = !!(window.location.pathname.match(/\/Location\//) && !this.vdrag);
    var rect = [ 'l', 't', 'r', 'b' ];
    var species, r, c;
    
    this.elLk.areas.each(function () {
      c = { a: this };
      
      if (this.shape && this.shape.toLowerCase() != 'rect') {
        c.c = [];
        $.each(this.coords.split(/[ ,]/), function () { c.c.push(parseInt(this)); });
      } else {
        $.each(this.coords.split(/[ ,]/), function (i) { c[rect[i]] = parseInt(this); });
      }
      
      myself.areas.push(c);
      
      if (this.className.match(/drag/)) {
        myself.draggables.push(c);
        
        if (highlight === true) {
          r = this.href.split('|');
          species = r[3];
          
          if (myself.multi || species == Ensembl.species) {
            if (!myself.highlightRegions[species]) {
              myself.highlightRegions[species] = [];
              myself.speciesCount++;
            }
            
            myself.highlightRegions[species].push({ region: c, linked: false });
            myself.imageNumber = parseInt(r[2]);
            
            Ensembl.EventManager.trigger('highlightImage', myself.imageNumber, species, parseInt(r[5]), parseInt(r[6]));
          }
        }
      }
    });
    
    this.elLk.img.mousedown(function (e) {
      // Only draw the drag box for left clicks.
      // This property exists in all our supported browsers, and browsers without it will draw the box for all clicks
      if (!e.which || e.which == 1) {
        myself.dragStart(e);
      }
      
      return false;
    }).click(function (e) {
      if (myself.clicking) {
        myself.makeZMenu(e, myself.getMapCoords(e));
      } else {
        myself.clicking = true;
      }
    });
  },
  
  dragStart: function (e) {
    var myself = this;
    var i = this.draggables.length;
    
    this.dragCoords.map = this.getMapCoords(e);
    this.dragCoords.page = { x: e.pageX, y : e.pageY };
    
    // Have to use this instead of the map coords because IE can't cope with offsetX/Y and relative positioned elements
    this.dragCoords.offset = { x: e.pageX - this.dragCoords.map.x, y: e.pageY - this.dragCoords.map.y }; 
    
    this.dragRegion = this.getArea(this.dragCoords.map.x, this.dragCoords.map.y, true);
    
    if (this.dragRegion) {
      this.elLk.img.mousemove(function (e2) {
        myself.dragging = e; // store mousedown event
        myself.drag(e2);
        return false;
      });
    }
  },
  
  dragStop: function (e) {
    this.elLk.img.unbind('mousemove');
    
    if (this.dragging !== false) {
      var diff = { 
        x: e.pageX - this.dragCoords.page.x, 
        y: e.pageY - this.dragCoords.page.y
      };
      
      // Set a limit below which we consider the event to be a click rather than a drag
      if (Math.abs(diff.x) < 3 && Math.abs(diff.y) < 3) {
        this.clicking = true; // Chrome fires mousemove even when there has been no movement, so catch clicks here
        this.makeZMenu(this.dragging, this.dragCoords.map); // use the original mousedown (stored in this.dragging) to create the zmenu
      } else {
        var range = this.vdrag ? { r: diff.y, s: this.dragCoords.map.y } : { r: diff.x, s: this.dragCoords.map.x };
        
        this.makeZMenu(e, range);
        
        this.dragging = false;
        this.clicking = false;
      }
    }
  },
  
  drag: function (e) {
    var coords = {};
    var x = e.pageX - this.dragCoords.offset.x;
    var y = e.pageY - this.dragCoords.offset.y;
    
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
    
    this.highlight(coords, 'rubberband');
  },
  
  makeZMenu: function (e, coords) {
    var area = coords.r ? this.dragRegion : this.getArea(coords.x, coords.y);
    
    if (!area) {
      return;
    }
    
    if ($(area.a).hasClass('nav')) {
      window.location = area.a.href;
      return;
    }
    
    var id = 'zmenu_' + area.a.coords.replace(/[ ,]/g, '_');
    
    if ($(area.a).hasClass('das') && this.highlightRegions) {
      var species = Ensembl.species;
      
      if (this.speciesCount > 1) {
        var dragArea = this.getArea(coords.x, coords.y, true);
        
        if (dragArea) {
          species = dragArea.a.href.split('|')[3]
        }
        
        dragArea = null;
      }
      
      var range = this.highlightRegions[species][0].range;
      var location, fuzziness;
      
      if (range) {
        location = range.start + (range.scale * (coords.x - this.dragRegion.l));
        fuzziness = range.scale * 2; // Increase the size of the click so we can have some measure of certainty for returning the right menu
        
        coords.clickStart = Math.floor(location - fuzziness);
        coords.clickEnd = Math.ceil(location + fuzziness);
        
        if (coords.clickStart < range.start) {
          coords.clickStart = range.start;
        }
        
        if (coords.clickEnd > range.end) {
          coords.clickEnd = range.end;
        }
      }
    }
    
    Ensembl.EventManager.trigger('makeZMenu', id, { position: { left: e.pageX, top: e.pageY }, coords: coords, area: area });
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
  highlightImage: function (imageNumber, species, start, end) {
    // Make sure each image is highlighted based only on the next image on the page
    if (imageNumber - this.imageNumber > 1 || imageNumber - this.imageNumber < 0) {
      return;
    }
    
    var highlight;
    var i = this.highlightRegions[species].length;
    var link = true; // Defines if the highlighted region has come from another image or the url
    
    while (i--) {
      highlight = this.highlightRegions[species][i];
      
      if (!highlight.region.a) {
        break;
      }
      
      // r = [ '#drag', image number, species number, species name, region, start, end, strand ]
      var r = highlight.region.a.href.split('|');
      
      var min = parseInt(r[5]);
      var max = parseInt(r[6]);
      var scale = (max - min + 1) / (highlight.region.r - highlight.region.l); // bps per pixel on image
      
      // Don't draw the redbox on the first imagemap on the page
      if (parseInt(r[2]) != 1) {
        this.highlight(highlight.region, 'redbox', species);
      }
      
      // Highlighting base on self. Take start and end from Ensembl core parameters
      if (this.imageNumber == imageNumber) {
        if (Ensembl.multiSpecies[species]) {
          start = Ensembl.multiSpecies[species].location.start;
          end = Ensembl.multiSpecies[species].location.end;
        } else {
          start = Ensembl.location.start;
          end = Ensembl.location.end;
        }
          
        link = false;
      }
      
      var coords = {
        t: highlight.region.t + 2,
        b: highlight.region.b - 2,
        l: ((start - min) / scale) + highlight.region.l,
        r: ((end - min) / scale) + highlight.region.l
      };
      
      // Highlight unless it's the bottom image on the page
      if (start >= min && end <= max && (link === true || !(start == min && end == max))) {
        this.highlight(coords, 'redbox2', species);
      }
      
      // Ok to overwrite because the only time we have more than one highlightRegions is MultiContigView, where each species image is identical
      highlight.range = { start: min, end: max, scale: scale };
    }
  },
  
  highlight: function (coords, cl, species) {  
    var w = coords.r - coords.l + 1;
    var h = coords.b - coords.t + 1;
    var originalClass;
    
    var style = {
      l: { left: coords.l, width: 1, top: coords.t, height: h },
      r: { left: coords.r, width: 1, top: coords.t, height: h },
      t: { left: coords.l, width: w, top: coords.t, height: 1 },
      b: { left: coords.l, width: w, top: coords.b, height: 1 }
    };
    
    if (species) {
      originalClass = cl;
      cl = cl + '_' + species;
    }
    
    if (!$('.' + cl, this.el).length) {
      this.elLk.img.after(
        '<div class="' + cl + ' l"></div>' + 
        '<div class="' + cl + ' r"></div>' + 
        '<div class="' + cl + ' t"></div>' + 
        '<div class="' + cl + ' b"></div>'
      );
    }
    
    var els = $('.' + cl, this.el).each(function () {
      $(this).css(style[this.className.split(' ')[1]]);
    });
    
    if (species) {
      els.addClass(originalClass);
    }
    
    els = null;
  },
  
  getMapCoords: function (e) {
    return {
      x: e.originalEvent.layerX || e.originalEvent.offsetX || 0, 
      y: e.originalEvent.layerY || e.originalEvent.offsetY || 0
    };
  },
  
  getArea: function (x, y, draggables) {
    var test = false;
    var areas = draggables ? this.draggables : this.areas;
    var c;
    
    for (var i = 0; i < areas.length; i++) {
      c = areas[i];
      
      switch (c.a.shape.toLowerCase()) {
        case 'circle': test = this.inCircle(c.c, x, y); break;
        case 'poly':   test = this.inPoly(c.c, x, y); break;
        default:       test = this.inRect(c, x, y); break;
      }
      
      if (test === true) {
        return $.extend({}, c);
      }
    }
  },
  
  inRect: function (c, x, y) {
    return x >= c.l && x <= c.r && y >= c.t && y <= c.b;
  },
  
  inCircle: function (c, x, y) {
    return (x - c[0]) * (x - c[0]) + (y - c[1]) * (y - c[1]) <= c[2] * c[2];
  },

  inPoly: function (c, x, y) {
    var n = c.length;
    var t = 0;
    var x1, x2, y1, y2;
    
    for (var i = 0; i < n; i += 2) {
      x1 = c[i % n] - x;
      y1 = c[(i + 1) % n] - y;
      x2 = c[(i + 2) % n] - x;
      y2 = c[(i + 3) % n] - y;
      t += Math.atan2(x1*y2 - y1*x2, x1*x2 + y1*y2);
    }
    
    return Math.abs(t/Math.PI/2) > 0.01;
  }
});
