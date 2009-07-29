// $Revision$

Ensembl.Panel.ImageMap = Ensembl.Panel.Content.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    this.linked = false;
    this.dragging = false;
    this.clicking = true;
    this.dragCoords = {};
    
    this.region = {};
    this.areas = []; // TODO: do we need both areas and draggables?
    this.draggables = [];
    
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
    
    this.makeImageMap(); 
    
    $('.iexport a', this.el).click(function () {
      myself.elLk.exportMenu.css({ left: $(this).offset().left }).toggle();

      return false;
    });
  },
  
  makeImageMap: function () {
    var myself = this;
    
    var rect = [ 'l', 't', 'r', 'b' ];
    var c;
    
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
      }
    });
    
    if (this.draggables.length && !this.vdrag) {
      this.region = this.draggables[0];      
      Ensembl.EventManager.trigger('highlightImageMaps');
    }
    
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
    
    while (i--) {
      if (this.inRect(this.draggables[i], this.dragCoords.map.x, this.dragCoords.map.y)) {
        this.region = this.draggables[i];
        
        this.elLk.img.mousemove(function (e2) {
          myself.dragging = e; // store mousedown event
          myself.drag(e2);
          return false;
        });
        
        break;
      }
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
    
    if (x < this.region.l) {
      coords.l = this.region.l;
    } else if (x > this.region.r) {
      coords.r = this.region.r;
    }
    
    if (y < this.region.t) {
      coords.t = this.region.t;
    } else if (y > this.region.b) {
      coords.b = this.region.b;
    }
    
    this.highlight(coords, 'rubberband');
  },
  
  makeZMenu: function (e, coords) {
    var area;
    var id = 'zmenu_';
    
    if (coords.r) { 
      // Range select
      area = this.region;
    } else { 
      // Point select
      area = this.getArea(coords.x, coords.y);
    }
    
    if (!area) {
      return;
    }
    
    id += area.a.coords.replace(/[ ,]/g, '_');
    
    if (this.range) {
      var location = this.range.start + (this.range.scale * (coords.x - this.region.l));
      var fuzziness = this.range.scale * 2; // Increase the size of the click so we can have some measure of certainty for returning the right menu
      
      coords.clickStart = Math.floor(location - fuzziness);
      coords.clickEnd = Math.ceil(location + fuzziness);
      
      if (coords.clickStart < this.range.start) {
        coords.clickStart = this.range.start;
      }
      
      if (coords.clickEnd > this.range.end) {
        coords.clickEnd = this.range.end;
      }
    }
    
    Ensembl.EventManager.trigger('makeZMenu', id, { position: { left: e.pageX, top: e.pageY }, coords: coords, area: area });
  },
  
  highlightImage: function (start, end, link) {    
    if (this.linked === true) {
      return;
    }
    
    var r = this.region.a.href.split('|'); // Find bp range for the map
    var min = parseInt(r[5]);
    var max = parseInt(r[6]);
    var scale = (max - min + 1) / (this.region.r - this.region.l); // bps per pixel on image
    
    var coords = {
      t: this.region.t + 2,
      b: this.region.b - 2,
      l: ((start - min) / scale) + this.region.l,
      r: ((end - min) / scale) + this.region.l
    };
    
    // Don't draw the redbox on the first imagemap on the page
    if (parseInt(r[2]) != 1) {
      this.highlight(this.region, 'redbox');
    }
    
    if (link === true) {
      if (start >= min && end <= max) {
        this.highlight(coords, 'redbox2');
      }
    
      this.linked = true;
    } else if (start > min && end < max) {
      // In this case start and end have come from Ensembl.location, so don't draw the red box if start = min and end = max
      this.highlight(coords, 'redbox2');
    }
    
    this.range = { start: min, end: max, scale: scale };
  },
  
  highlight: function (coords, cl) {  
    var w = coords.r - coords.l + 1;
    var h = coords.b - coords.t + 1;
    
    var styleL = { left: coords.l, width: 1, top: coords.t, height: h };
    var styleR = { left: coords.r, width: 1, top: coords.t, height: h };
    var styleT = { left: coords.l, width: w, top: coords.t, height: 1 };
    var styleB = { left: coords.l, width: w, top: coords.b, height: 1 };
    
    if (!$('.' + cl, this.el).length) {
      this.elLk.img.after(
        '<div class="' + cl + ' l"></div>' + 
        '<div class="' + cl + ' r"></div>' + 
        '<div class="' + cl + ' t"></div>' + 
        '<div class="' + cl + ' b"></div>'
      );
    }
    
    var divs = $('.' + cl, this.el);
    
    divs.filter('.l').css(styleL);
    divs.filter('.r').css(styleR);
    divs.filter('.t').css(styleT);
    divs.filter('.b').css(styleB);
    
    divs = null;
  },
  
  getMapCoords: function (e) {
    return {
      x: e.originalEvent.layerX || e.originalEvent.offsetX || 0, 
      y: e.originalEvent.layerY || e.originalEvent.offsetY || 0
    };
  },
  
  getArea: function (x, y) {
    var test = false;
    var c;
    
    for (var i = 0; i < this.areas.length; i++) {
      c = this.areas[i];
      
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
