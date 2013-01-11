// $Revision$

/*
 * JavaScript to dynamically change form action on the UserData upload page according to the option selected (or radio buttons checked) and do validation on the form
 */

Ensembl.Panel.UserData = Ensembl.Panel.ModalContent.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    // in case this panel is added by addSubPanel method, it misses getting references to content and links
    if (!this.elLk.content.length) {
      this.elLk.content = this.el.parents('.modal_wrapper');
      this.elLk.links   = this.elLk.content.siblings('.modal_nav').find('ul.local_context li');
    }
    
    this.elLk.form            = this.el.find('form').validate().off('.UserData').on('submit.UserData', function () { return panel.formSubmit($(this)); });
    this.elLk.requiredInputs  = this.elLk.form.find(':input.required');
    this.elLk.errorMessage    = this.elLk.form.find('label._userdata_upload_error').addClass('invalid');
    this.elLk.actionInputs    = this.elLk.form.find(':input._action').each(function () {
      $(this).off('.UserData').on('change.UserData', function () {
        // change the form action according to the dropdown/radio buttons (if <select> is changed, give priority to radio buttons if they are visible)
        var action = this.nodeName === 'SELECT' ? panel.elLk.actionInputs.filter('input:visible:checked')[0] || $(this).find('option:selected')[0] : this;
            action = action ? (action.className.match(/(?:\s+|^)_action_([^\s]+)/) || []).pop() || '' : '';
        
        if (action) {
          panel.elLk.form.toggleClass('upload', action === 'upload').attr('action', panel.elLk.form.find('input[name=' + action + ']').val());
        }
        
        panel.elLk.form.validate();     // Apply/remove the validation to/from individual input field
        panel.elLk.errorMessage.hide(); // reset any validation error messages
        
        var visibleInps = panel.elLk.requiredInputs.validate(false).filter(':visible');
        
        if (visibleInps.length === 1) {
          visibleInps.validate(true);
        } else {
          // validate only if any value is entered in the inputs, ignore any null value
          visibleInps.off('.UserData').on({
            'keyup.UserData': function (e) {
              if (e.keyCode !== 9) { // ignore TAB
                $(this).validate(!!this.value);
                
                if (e.keyCode !== 13) { // ignore ENTER
                  panel.elLk.errorMessage.hide();
                }
              }
            },
            'change.UserData': function () {
              panel.elLk.errorMessage.hide();
            }
          });
        }
      });
    }).filter('select').validate(true).end(); // not to forget validating the dropdown to select the format
  },
  
  formSubmit: function(form, data) {
    
    var visibleInps = this.elLk.requiredInputs.filter(':visible');
    
    // if neither of the multiple inputs have any value
    if (visibleInps.length > 1 && visibleInps.filter(function () { return !!this.value; }).length === 0) {
      this.elLk.errorMessage.show();
      return false;
    }
    
    this.elLk.links.removeClass('active');
    
    return this.base(form, data);
  }
});
