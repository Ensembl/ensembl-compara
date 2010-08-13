// $Revision$

Ensembl.Panel.Exporter = Ensembl.Panel.ModalContent.extend({
  init: function () {    
    this.base();
    this.filterInit();
  },
  
  filter: function (val) {
    this.elLk.fieldsets.hide().filter('.' + val).show();
  },
  
  filterInit: function () {
    var panel = this;
    
    this.elLk.outputTypes = $('fieldset.general_options', this.elLk.content).find('select.output_type').change(function () {
      panel.filter(this.value);
    });
  
    this.elLk.fieldsets = $('fieldset[class]:not(.general_options)', this.el);
    this.filter($('fieldset.general_options', this.el).find('select.output_type').val());
  },
  
  formSubmit: function (form) {
    var data = form.serialize();
    
    $('input.input-checkbox', form).each(function () {
      // Give the value of "no" for deselected checkboxes
      if (this.checked === false) {
        data += '&' + this.name + '=no';
      }
    });
    
    this.elLk.outputTypes.unbind();
    return this.base(form, data);
  },
  
  updateContent: function (json) {
    this.base(json);
    this.filterInit();
  }
});
