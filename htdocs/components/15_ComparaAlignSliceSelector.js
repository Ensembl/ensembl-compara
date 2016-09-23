Ensembl.Panel.ComparaAlignSliceSelector = Ensembl.Panel.extend({
  constructor: function (id) {
    this.base(id);
    Ensembl.EventManager.register('updateAlignmentSpeciesSelection', this, this.updateAlignmentSpeciesSelection);
  },
  
  init: function () {
    var panel = this;  
    panel.base();

    panel.elLk.form = $('form', panel.el);
    panel.elLk.selectedInput = $('form input.ss-alignment-selected-value', panel.el);
    panel.elLk.go = $('form a.alignment-go', panel.el);
  },

  updateAlignmentSpeciesSelection: function(item) {
    var panel = this;

    panel.elLk.selectedInput.val(item.value);
    var href = panel.elLk.go[0].href;
    if (href.match(/align=/)) {
      href = href.replace(/align=(\d+)/, 'align='+item.value);
    }
    else {
      href = href.replace(/;$/, '');
      href += ';align=' + item.value;
    }
    panel.elLk.form.submit();
  }
});
