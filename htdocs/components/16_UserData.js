/*
 * JavaScript to dynamically change form action on the UserData upload page according to the option selected (or radio buttons checked) and do validation on the form
 */

Ensembl.Panel.UserData = Ensembl.Panel.ModalContent.extend({ // inheriting ModalContent because it has the generic 'formSubmit' method
  init: function () {
    var panel = this;
    this.base();
    
    // form
    this.elLk.form = this.el.find('form').validate().on('submit.UserData', function() {
      var visibleInps = panel.elLk.requiredInputs.filter(':visible');
      if (visibleInps.length > 1 && visibleInps.filter(function () { return !!this.value; }).length === 0) {// if neither of the multiple inputs have any value
        panel.elLk.errorMessage.show();
        return false;
      }
      return panel.formSubmit($(this));
    });
    
    this.elLk.requiredInputs = this.elLk.form.find(':input.required');
    
    this.elLk.errorMessage = this.elLk.form.find('label._userdata_upload_error');
    
    this.elLk.actionInputs = this.elLk.form.find(':input._action').each(function() {
      $(this).on('change.UserData', function() {

        // change the form action according to the dropdown/radio buttons (if <select> is changed, give priority to radio buttons if they are visible)
        var action = this.nodeName === 'SELECT' ? panel.elLk.actionInputs.filter('input:visible:checked')[0] || $(this).find('option:selected')[0] : this;
            action = action ? (action.className.match(/(?:\s+|^)_action_([^\s]+)/) || []).pop() || '' : '';
        if (action) {
          panel.elLk.form.toggleClass('upload', action === 'upload').attr('action', panel.elLk.form.find('input[name=' + action + ']').val());
        }
        
        // Apply/remove the validation to/from individual input field
        panel.elLk.form.validate(); // reset any validation error messages
        panel.elLk.errorMessage.hide();
        var visibleInps = panel.elLk.requiredInputs.validate(false).filter(':visible');
        if (visibleInps.length === 1) {
          visibleInps.validate(true);
        } else {  // validate only if any value is entered in the inputs, ignore any null value
          visibleInps.off('.UserData').on({
            'keyup.UserData': function (e) {
              if (e.keyCode !== 9) { // ignore TAB
                $(this).validate(!!this.value);
                if (e.keyCode !== 13) { // ignore TAB & ENTER
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
  }
});