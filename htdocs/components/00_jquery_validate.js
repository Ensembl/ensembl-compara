// $Revision$

/*
 * This is based loosely on the jQuery validation plugin 1.6 available at 
 * http://bassistance.de/jquery-plugins/jquery-plugin-validation/
 * http://docs.jquery.com/Plugins/Validation
 * 
 * I wrote my own version after it became too frustrating to customise for usage in EnsEMBL
 * This plugin is much less customisable, but hey, it does what we want and I'm not putting
 * it out on the web.
 * 
 * Simon Brent
 */

(function($) {

$.extend($.fn, {
  validate: function (options) {
    if (this.length && this.attr('tagName') == 'FORM') {
      var validator = $.data(this[0], 'validator');
      
      if (!validator) {
        validator = new $.validator(options, this[0]);
        $.data(this[0], 'validator', validator); 
      }
      
      validator.validateInputs(null, 'initial');
    }
    
    return this;
  }
});

$.validator = function (options, form) {
  var validator = this;
  
  this.settings      = $.extend({}, $.validator.defaults, options);
  this.rules         = this.settings.rules;
  this.form          = form;
  this.inputs        = $('input[type="text"], input[type="password"], textarea', form);
  this.submitButtons = $('input[type="submit"]', form);
  
  this.inputs.each(function () {
    $.data(this, 'valid', true);
    
    if (!this.className) return;
    
    if ($(this).hasClass(validator.settings.requiredClass)) $.data(this, 'required', true);
    
    var rule = this.className.match(/.*\b_(\w+)\b.*/);
    
    if (!rule) return;
    
    $.data(this, 'rule', rule[1]);
    
    var min = this.className.match(/\bmin_(\d+)\b/);
    var max = this.className.match(/\bmax_(\d+)\b/);
    
    if (min) $.data(this, 'min', parseFloat(min[1], 10));
    if (max) $.data(this, 'max', parseFloat(max[1], 10));
  }).bind({
    keyup:  function (e) { if (e.keyCode != 9) validator.validateInputs($(this), 'delay'); }, // Ignored if the tab key is pressed, since this will cause blur to fire
    change: function ()  { validator.validateInputs($(this), 'delay'); },
    blur:   function ()  { validator.validateInputs($(this), 'showError'); }
  });
};

$.extend($.validator, {
  defaults: {
    validClass:    'valid',
    invalidClass:  'invalid',
    requiredClass: 'required',
    rules: {
      'int':     function (val) { return /^[-+]?\d+$/.test(val);             },
      nonnegint: function (val) { return /^[-+]?\d+$/.test(val) && val >= 0; },
      posint:    function (val) { return /^[-+]?\d+$/.test(val) && val >  0; },
      password:  function (val) { return /^\S{6,32}$/.test(val);             },
      email: function (val) {
        return /^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i.test(val);
      },
      url: function (val) {
        return /^(https?|ftp):\/\/(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(\#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i.test(val);
      }
    },
    messages: {
      required:  'This field is required',
      'int':     'Please enter an integer',
      nonnegint: 'Please enter an integer (minimum 0)',
      posint:    'Please enter an integer (minimum 1)',
      password:  'The password you have entered is invalid',
      email:     'Please enter a valid email address',
      url:       'Please enter a valid URL'
    }
  },
  
  prototype: {
    validateInputs: function (inputs, flag) {
      inputs = inputs || this.inputs;
      
      var validator = this;
      
      var setClass = {
        'true':  function (el) { $(el).removeClass(validator.settings.invalidClass).addClass(validator.settings.validClass); },
        'false': function (el) { $(el).removeClass(validator.settings.validClass).addClass(validator.settings.invalidClass); },
        'null':  function (el) { $(el).removeClass(validator.settings.validClass + ' ' + validator.settings.invalidClass);   }
      };
      
      clearTimeout(this.timeout);
      
      this.timeout = setTimeout(function () {
        inputs.each(function () {
          var required = $.data(this, 'required')
          var error    = $.data(this, 'error');
          var rule     = $.data(this, 'rule');
          var min      = $.data(this, 'min');
          var max      = $.data(this, 'max');
          
          var state = (flag == 'initial' || !required) && !this.value ? null :            // Not required and no value - do nothing. On initial run, ignore empty fields
                      rule && validator.rules[rule] ? validator.rules[rule](this.value) : // Validate against rule
                      required ? !!this.value : null;                                     // No rule - check if required
          
          if (state && min) state = parseFloat(this.value, 10) >= min;
          if (state && max) state = parseFloat(this.value, 10) <= max;
          
          setClass[state](this);
          $.data(this, 'valid', state);
          
          if (state === false) {
            if (required && !this.value) rule = 'required';
            
            var message = validator.settings.messages[rule];
            
            if (rule.match(/int$/)) {
              if (min && max) {
                message = 'Please enter an integer between ' + min + ' and ' + max;
              } else if (min || max) {
                message = 'Please enter an integer (' + (min ? 'min' : 'max') + 'imum ' + (min || max) + ')';
              }
            }
            
            if (!error) {
              error = {
                rule: rule,
                el: $('<label>', { 
                  className: validator.settings.invalidClass, 
                  'for':     this.id, 
                  html:      message
                }).hide().appendTo($(this).parent())
              }
              
              $.data(this, 'error', error);
            } else if (error.rule != rule) {
              error.el.html(message);
              error.rule = rule;
            }
            
            if (flag == 'showError') error.el.show();
          } else if (error) {
            error.el.remove();
            $.data(this, 'error', false);
          }
        });
        
        var isValid = true;
        
        for (var i in validator.inputs.toArray()) {
          if ($.data(validator.inputs[i], 'valid') === false) {
            isValid = false;
            break;
          }
        }
        
        if (isValid) {
          validator.submitButtons.attr('disabled', '').removeClass('disabled');
        } else {
          validator.submitButtons.attr('disabled', 'disabled').addClass('disabled');
        }
      }, flag == 'delay' ? 250 : 0);
    }
  }
});

})(jQuery);
