// $Revision$

Ensembl.Panel.Configurator = Ensembl.Panel.ModalContent.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    Ensembl.EventManager.register('updateConfiguration', this, this.updateConfiguration);
    Ensembl.EventManager.register('showConfiguration',   this, this.show);
  },
  
  init: function () {
    this.base();
    
    this.elLk.form = $('form.configuration', this.el);
    
    this.initialConfig = {};
    
    if (this.params.hash) {
      this.elLk.links.removeClass('active').has('.' + this.params.hash).addClass('active');
      delete this.params.hash;
    }
  },
  
  show: function (active) {
    if (active) {
      this.elLk.links.removeClass('active').has('.' + active).addClass('active');
    }
    
    this.base();
    this.getContent();
  },
  
  updateConfiguration: $.noop,
  
  updatePage: function (data, delayReload) {
    data.submit = 1;
    
    $.ajax({
      url:  this.elLk.form.attr('action'),
      type: this.elLk.form.attr('method'),
      data: data, 
      dataType: 'json',
      context: this,
      success: function (json) {
        if (json.updated) {
          Ensembl.EventManager.trigger('queuePageReload', this.imageConfig, !delayReload);
        } else if (json.redirect) {
          Ensembl.redirect(json.redirect);
        }
      }
    });
  }
});
