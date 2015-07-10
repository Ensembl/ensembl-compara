Ensembl.Panel.RegButtons = Ensembl.Panel.Content.extend({
  constructor: function (id, params) {
    this.base(id, params);
    Ensembl.EventManager.register('partialReload', this, this.partialReload);
  },

  partialReload: function() {
    Ensembl.EventManager.triggerSpecific('updatePanel',this.id,null,null,null,null,{ background: true });  
  }
});    
