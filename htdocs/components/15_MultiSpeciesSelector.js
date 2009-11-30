// $Revision$

Ensembl.Panel.MultiSpeciesSelector = Ensembl.Panel.MultiSelector.extend({
  updateSelection: function () {
    var existingSelection = {};
    var i, j;
    
    for (i in Ensembl.multiSpecies) {
      existingSelection[Ensembl.multiSpecies[i].s] = parseInt(i);
    }
    
    var params = [];
    
    for (i = 0; i < this.selection.length; i++) {
      j = existingSelection[this.selection[i]];
      
      if (typeof j != 'undefined') {
        $.each(['r', 'g', 's'], function () {
          if (Ensembl.multiSpecies[j][this]) {
            params.push(this + (i + 1) + '=' + Ensembl.multiSpecies[j][this]);
          }
        });
      } else {
        params.push('s' + (i + 1) + '=' + this.selection[i]);
      }
    }
    
    if (this.selection.join(',') != this.initialSelection) {
      Ensembl.redirect(this.elLk.form.attr('action') + '?' + Ensembl.cleanURL(this.elLk.form.serialize() + ';' + params.join(';')));
    }
    
    return true;
  }
});