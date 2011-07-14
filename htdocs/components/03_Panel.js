// $Revision$

Ensembl.Panel = Base.extend({  
  constructor: function (id, params) {
    if (typeof id !== 'undefined') {
      this.id = id;
    }
    
    this.params = typeof params === 'undefined' ? {} : params;
    
    this.initialised = false;
  },
  
  destructor: function (action) {
    var el;
    
    if (action === 'empty') {
      this.el.empty();
    } else if (action !== 'cleanup') {
      this.el.remove();
    }
    
    for (el in this.elLk) {
      this.elLk[el] = null;
    }
    
    for (el in this.live) {
      this.live[el].die();
      this.live[el] = null;
    }
    
    this.el = null;
  },
  
  init: function () {
    var panel = this;
    
    if (this.initialised) {
      return false;
    }
    
    this.el = $('#' + this.id);
    
    if (!this.el.length) {
      throw new Error('Could not find ' + this.id + ', perhaps DOM is not ready');
    }
    
    this.elLk = {};
    this.live = [];
    
    $('input.js_param', this.el).each(function () {
      if (!panel.params[this.name]) {
        panel.params[this.name] = this.value;
      }
    });
    
    this.initialised = true;
  },
  
  hide: function () {    
    this.el.hide();
  },
  
  show: function () {
    this.el.show();
  },
  
  height: function (h) {
    return this.el.height(h);
  },
  
  width: function (w) {
    return this.el.width(w);
  }
});
