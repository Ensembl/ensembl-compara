// $Revision$
// Hides options in 'conversion' that don't match the current value in 'species'

Ensembl.Panel.AssemblyMappings = Ensembl.Panel.extend({
  init: function () {
    var panel = this;
    this.base();
    
    this.elLk.conversion = $('.conversion', this.el);
    this.elLk.species    = $('.dropdown_remotecontrol', this.el).bind('change', function () { panel.showBySpecies(); });
    
    this.showBySpecies();
  },
  
  showBySpecies: function () {
    this.elLk.conversion.children().hide().filter(':selected').removeAttr('selected').end()
      .filter('.' + this.elLk.species.val()).show().first().attr('selected', 'selected');
  }
});
