// $Revision$

Ensembl.Panel.Exporter = Ensembl.Panel.ModalContent.extend({
  init: function () {
    var panel = this;
    
    this.base();
    this.filterInit();
    
    this.config = {};
    
    $.each($('form.configuration', this.el).serializeArray(), function () { panel.config[this.name] = this.value; });
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
    var panel   = this;
    var checked = $.extend({}, this.config);
    var data    = {};
    var diff    = {};
    var i;
    
    $('input[type=hidden]', form).each(function () { data[this.name] = this.value; });
    
    if (form.hasClass('configuration')) {
      $.each(form.serializeArray(), function () {
        if (panel.config[this.name] !== this.value) {
          diff[this.name] = this.value;
        }

        delete checked[this.name];
      });

      // Add unchecked checkboxes to the diff
      for (i in checked) {
        diff[i] = 'no';
      }
      
      data.view_config = JSON.stringify(diff);
      
      $.extend(true, this.config, diff);
    }
    
    this.elLk.outputTypes.unbind();
    
    return this.base(form, data);
  },
  
  updateContent: function (json) {
    this.base(json);
    this.filterInit();
  }
});
