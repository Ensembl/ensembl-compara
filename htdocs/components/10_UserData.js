/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// JavaScript to dynamically change form action on the UserData upload page according to the option selected (or radio buttons checked) and do validation on the form

Ensembl.Panel.UserData = Ensembl.Panel.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    this.elLk.activeLink      = this.el.parents('.modal_wrapper').siblings('.modal_nav').find('ul.local_context li.active');
    this.elLk.form            = this.el.find('form').validate().off('.UserData').on('submit.UserData', function (e) { e.preventDefault(); panel.formSubmit(); });
    this.elLk.requiredInputs  = this.elLk.form.find(':input.required');
    this.elLk.errorMessage    = this.elLk.form.find('label._userdata_upload_error').addClass('invalid');
    this.elLk.actionInputs    = this.elLk.form.find(':input._action').off('.UserData').on('change.UserData', function () {
    
      $(this).selectToToggle('trigger');
      
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
    }).filter('select').validate(true).end(); // not to forget validating the dropdown to select the format
  },
  
  formSubmit: function () {
    if (!this.elLk.requiredInputs.filter(function() { return this.value && $(this).is(':visible'); }).length) {
      this.elLk.errorMessage.show();
      return false;
    }
    
    this.elLk.activeLink.removeClass('active');
    
    return Ensembl.EventManager.trigger('modalFormSubmit', this.elLk.form);
  }
});
