// $Revision$

Ensembl.Panel.Exporter = Ensembl.Panel.ModalContent.extend({
  init: function () {
    var panel = this;
    
    this.base();
    this.filterInit();
    
    $('fieldset.general_options', this.elLk.content).find('select.output_type').live('change', function () {
      panel.filter(this.value);
    });
  },
  
  filter: function (val) {
    this.elLk.fieldsets.hide().filter('.' + val).show();
  },
  
  filterInit: function () {
    this.elLk.fieldsets = $('fieldset[class]:not(.general_options', this.el);
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
    
    this.base(form, data);
  },
  
  updateContent: function (json) {
    this.base(json);
    this.filterInit();
  }
});
