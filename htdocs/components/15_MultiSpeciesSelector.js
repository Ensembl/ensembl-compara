// $Revision$

Ensembl.Panel.MultiSpeciesSelector = Ensembl.Panel.MultiSelector.extend({
  updateSelection: function () {
    var params = [ 's', 'r', 'g' ]; // Multi-species parameters
    var existingSelection = {};
    var urlParams = [];
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
            urlParams.push(params[k] + (i + 1) + '=' + Ensembl.multiSpecies[j][params[k]]);
          }
        }
      } else {
        urlParams.push('s' + (i + 1) + '=' + this.selection[i]);
      }
    }
    
    if (this.selection.join(',') != this.initialSelection) {
      Ensembl.redirect(this.elLk.form.attr('action') + '?' + Ensembl.cleanURL(this.elLk.form.serialize() + ';' + urlParams.join(';')));
    }
    
    return true;
  }
});