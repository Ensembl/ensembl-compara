// $Revision$

Ensembl.Panel.MultiSpeciesSelector = Ensembl.Panel.MultiSelector.extend({
  updateSelection: function () {
    var params            = [ 's', 'r', 'g' ]; // Multi-species parameters
    var existingSelection = {};
    var urlParams         = [];
    var species           = [];
    var i, j, k;
    
    for (var s in Ensembl.multiSpecies) {
      existingSelection[Ensembl.multiSpecies[s].s] = parseInt(s, 10);
    }
    
    for (i = 0; i < this.selection.length; i++) {
      j = existingSelection[this.selection[i]];
      
      if (typeof j != 'undefined') {       
        k = params.length;
        
        while (k--) {
          if (Ensembl.multiSpecies[j][params[k]]) {
            if (params[k] === 's') {
              species.push('s' + (i + 1) + '=' + Ensembl.multiSpecies[j].s)
            } else {
              urlParams.push(params[k] + (i + 1) + '=' + Ensembl.multiSpecies[j][params[k]]);
            }
          }
        }
      } else {
        species.push('s' + (i + 1) + '=' + this.selection[i]);
      }
    }
    
    if (this.selection.join(',') != this.initialSelection) {
      $.ajax({
        url: '/' + Ensembl.species + '/Ajax/multi_species?' + species.join(';'),
        context: this,
        complete: function () {
          Ensembl.redirect(this.elLk.form.attr('action') + '?' + Ensembl.cleanURL(this.elLk.form.serialize() + ';' + species.join(';') + ';' + urlParams.join(';')));
        }
      });
    }
    
    return true;
  }
});