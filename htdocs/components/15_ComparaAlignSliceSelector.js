Ensembl.Panel.ComparaAlignSliceSelector = Ensembl.Panel.extend({
  constructor: function (id) {
    this.base(id);
    Ensembl.EventManager.register('updateAlignmentSpeciesSelection', this, this.updateAlignmentSpeciesSelection);
    Ensembl.EventManager.register('updateMultipleAlignmentSpeciesSelection', this, this.updateMultipleAlignmentSpeciesSelection);
  },
  
  init: function () {
    var panel = this;  
    panel.base();

    panel.elLk.form = $('form', panel.el);
    panel.elLk.selectedInput = $('form input.ss-alignment-selected-value', panel.el);
    panel.elLk.go = $('form a.alignment-go', panel.el);
    panel.configUrl = $('input.compara_config_url', panel.el).val();
    panel.updateComponent = $('input.update_component', panel.el).val();
  },

  updateAlignmentSpeciesSelection: function(node) {
    var panel = this;

    panel.elLk.selectedInput.val(node.data.value);
    var href = panel.elLk.go[0].href;
    if (href.match(/align=/)) {
      href = href.replace(/align=(\d+)/, 'align='+node.data.value);
    }
    else {
      href = href.replace(/;$/, '');
      href += ';align=' + node.data.value;
    }
    panel.elLk.form.submit();
  },

  updateMultipleAlignmentSpeciesSelection: function(node) {
    var selection = {};
    selection[Ensembl.species] = {};

    // Update config first
    $.each(node.childList, function(i, child) {
      selection[Ensembl.species][child.data.key] = child.bSelected ? 'yes' : 'off';
    });

    selection[Ensembl.species]['align'] = node.data.value;

    $.ajax({
      url:  this.configUrl,
      type: 'POST',
      data: { 'alignment_selector': JSON.stringify(selection), 'submit': 1 },
      traditional: true,
      dataType: 'json',
      async: false,
      context: this,
      success: function (json) {
        if (json.updated) {
          var align_id = this.elLk.selectedInput.val();

          // If no alignment selected on page load then submit the new alignment selected
          if (!align_id || align_id !== node.data.value) {
            this.updateAlignmentSpeciesSelection(node);
          }
          else {
            this.elLk.selectedInput.val(node.data.value);
            Ensembl.EventManager.trigger('queuePageReload', this.updateComponent, true);
          }

        }
      }
    });
  }
});
