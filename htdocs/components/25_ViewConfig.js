// $Revision$

Ensembl.Panel.ViewConfig = Ensembl.Panel.Configurator.extend({  
  init: function () {
    var panel = this;
    
    this.base();
    
    $.each(this.elLk.form.serializeArray(), function () { panel.initialConfig[this.name] = this.value; });
    
    this.getContent();
  },
  
  getContent: function () {
    var active = this.elLk.links.filter('.active').children('a')[0];
    
    if (typeof active === 'undefined') {
      active = this.elLk.links.first().addClass('active').children('a').attr('className');
    } else {
      active = active.className;
    }
    
    if (typeof active !== 'undefined') {
      $('> div', this.elLk.form).hide().filter('.' + active).show();
    }
  },
  
  updateConfiguration: function (delayReload) {
    if ($('input.invalid', this.elLk.form).length) {
      return;
    }
    
    var panel   = this;
    var d       = false;
    var diff    = {};
    var checked = $.extend({}, this.initialConfig);
    var i;
    
    $.each(this.elLk.form.serializeArray(), function () {
      if (panel.initialConfig[this.name] !== this.value) {
        diff[this.name] = this.value;
        d = true;
      }
      
      delete checked[this.name];
    });
    
    // Add unchecked checkboxes to the diff
    for (i in checked) {
      diff[i] = 'off';
      d = true;
    }
    
    if (d === true) {
      $.extend(true, this.initialConfig, diff);
      
      this.updatePage(diff, delayReload);
      
      return d;
    }
  }
});
