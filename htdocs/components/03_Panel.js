// $Revision$

Ensembl.Panel = Base.extend({  
  constructor: function (id, params) {
    if (typeof id != 'undefined') {
      this.id = id;
    }
    
    this.params = typeof params == 'undefined' ? {} : params;
    
    this.initialised = false;
  },
  
  destructor: function (empty) {
    $('*', this.el).unbind();
    
    if (empty === true) {
      $(this.el).empty();
    } else {
      $(this.el).remove();
    }
    
    for (var el in this.elLk) {
      this.elLk[el] = null;
    }
    
    this.el = null;
  },
  
  init: function () {
    if (this.initialised) {
      return false;
    }
    
    this.el = document.getElementById(this.id);
    
    if (this.el === null) {
      throw new Error('Could not find ' + this.id + ', perhaps DOM is not ready');
    }
    
    this.elLk = {};
    
    this.initialised = true;
  },
    
  height: function (h) {
    if (typeof h == 'undefined') {
      return this.getStyle('height');
    } else {
      this.setDim(h);
    }
  },
  
  width: function (w) {
    if (typeof w == 'undefined') {
      return this.getStyle('width');
    } else {
      this.setDim(w);
    }
  },
  
  hide: function () {    
    this.el.style.display = 'none';
    this.visible = false;
  },
  
  show: function () {
    this.el.style.display = 'block';
    this.visible = true;
  },
  
  setDim: function (w, h) {
    if (typeof w != 'undefined') {
      if (typeof w != 'string') {
        w = w.toString() + 'px';
      }
      
      this.el.style.width = w;
    }
        
    if (typeof h != 'undefined') {
      if (typeof h != 'string') {
        h = h.toString() + 'px';
      }
      
      this.el.style.height = h;
    }
  },
  
  getStyle: function (styleProp) {
    var y = null;
    
    if (this.el.currentStyle) {
      y = this.el.currentStyle[styleProp];
    } else if (window.getComputedStyle) {
      y = document.defaultView.getComputedStyle(this.el, null).getPropertyValue(styleProp);
    }
    
    return y;
  }
});
