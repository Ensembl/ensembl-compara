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
    return this.each(function () {
      if (this.nodeName === 'FORM') {
        var validator = $(this).data('validator');
        
        if (!validator) {
          validator = new $.validator(options, this);
          $(this).data('validator', validator); 
        }
        
        validator.validateInputs(null, 'initial');
      } else {
        if (this.nodeName.match(/SELECT|INPUT|TEXTAREA/)) {
          var inp = $(this);
          if (inp.parents('form').data('validator')) {
            inp.data('required', options === false ? false : true);
          }
        }
      }
    });
  }
});

$.validator = function (options, form) {
  var validator = this;
  
  this.settings      = $.extend({}, $.validator.defaults, options);
  this.rules         = this.settings.rules;
  this.tests         = this.settings.tests; // Precompiled regular expressions
  this.inputs        = $('input[type="text"], input[type="password"], input[type="file"], textarea, select', form);
  this.submitButtons = $('input[type="submit"]', form);
  this.result        = true;
  
  $(form).on('submit.validate', function (e) {
    validator.result = true;
    validator.validateInputs(null, 'showError');
    
    if (!validator.result) {
      e.stopImmediatePropagation();
      e.preventDefault();
    }
  });
  
  this.inputs.each(function () {
    var el    = $(this);
    var input = { valid: true };
    
    if (this.className) {
      if (el.hasClass(validator.settings.requiredClass)) {
        input.required = true;
      }
      
      var rule = this.className.match(/.*\b_(\w+)\b.*/);
      
      if (rule) {
        input.rule = rule[1];
        
        var min = this.className.match(/\bmin_(.+)\b/);
        var max = this.className.match(/\bmax_(.+)\b/);
        
        if (min) {
          input.min = parseFloat(min[1], 10);
        }
        
        if (max) {
          input.max = parseFloat(max[1], 10);
        }
      }
    }
    
    el.data(input);
    
    el = null;
  }).on({
    'keyup.validate':  function (e) { if (e.keyCode !== 9) { validator.validateInputs($(this), 'delay'); } }, // Ignored if the tab key is pressed, since this will cause blur to fire
    'change.validate': function ()  { validator.validateInputs($(this), 'delay'); },
    'blur.validate':   function ()  { validator.validateInputs($(this), 'showError'); }
  });
  
  form = null;
};

$.extend($.validator, {  
  defaults: {
    validClass:    'valid',
    invalidClass:  'invalid',
    requiredClass: 'required',
    tests: {
      'int':    new RegExp(/^[\-+]?\d+$/),
      'float':  new RegExp(/^([\-+]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([\-+]?\d+))?$/),
      password: new RegExp(/^\S{6,32}$/),
      email:    new RegExp(/^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i),
      url:      new RegExp(/^(https?|ftp):\/\/(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(\#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i)
    },
    rules: {
      nonnegint:   function (val) { return this.tests['int'].test(val)   && val >= 0; },
      posint:      function (val) { return this.tests['int'].test(val)   && val >  0; },
      nonnegfloat: function (val) { return this.tests['float'].test(val) && val >= 0; },
      posfloat:    function (val) { return this.tests['float'].test(val) && val >  0; }
    },
    messages: {
      required:    'This field is required',
      'int':       'Please enter an integer',
      nonnegint:   'Please enter an integer (minimum 0)',
      posint:      'Please enter an integer (minimum 1)',
      'float':     'Please enter a number',
      nonnegfloat: 'Please enter a number (minimum 0)',
      posfloat:    'Please enter a number (minimum 1)',
      password:    'The password you have entered is invalid',
      email:       'Please enter a valid email address',
      url:         'Please enter a valid URL'
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
      
      function validate() {
        var isValid = true;
        var i;
        
        inputs.each(function () {
          var el    = $(this);
          var input = $.extend({}, el.data());
          
          var state = (flag === 'initial' || !input.required) && !this.value ? null :                                       // Not required and no value - do nothing. On initial run, ignore empty fields
                      input.rule && validator.rules[input.rule] ? validator.rules[input.rule].call(validator, this.value) : // Validate against rule
                      input.rule && validator.tests[input.rule] ? validator.tests[input.rule].test(this.value) :            // Validate against test
                      input.required ? !!this.value : null;                                                                 // No rule - check if required
          
          if (state && input.min) {
            state = parseFloat(this.value, 10) >= input.min;
          }
          
          if (state && input.max) {
            state = parseFloat(this.value, 10) <= input.max;
          }
          
          setClass[state](this);
          el.data('valid', state);
          
          if (state === false) {
            if (input.required && !this.value) {
              input.rule = 'required';
            }
            
            var message = validator.settings.messages[input.rule];
            
            if (input.rule.match(/int$/)) {
              if (input.min && input.max) {
                message = 'Please enter an integer between ' + input.min + ' and ' + input.max;
              } else if (input.min || input.max) {
                message = 'Please enter an integer (' + (input.min ? 'min' : 'max') + 'imum ' + (input.min || input.max) + ')';
              }
            }
            
            if (!input.error) {
              input.error = {
                rule: input.rule,
                el: $('<label>', { 
                  'class': validator.settings.invalidClass, 
                  'for':   this.id, 
                  html:    message
                }).hide().appendTo(el.parent())
              };
              
              el.data('error', input.error);
            } else if (input.error.rule !== input.rule) {
              input.error.el.html(message);
              input.error.rule = input.rule;
            }
            
            if (flag === 'showError') {
              input.error.el.css('display', 'inline');
            }
          } else if (input.error) {
            input.error.el.remove();
            el.data('error', false);
          }
          
          el = null;
        });
        
        for (i in validator.inputs.toArray()) {
          if ($(validator.inputs[i]).data('valid') === false) {
            isValid = false;
            break;
          }
        }
        
        if (typeof validator.settings.validate === 'function') {
          isValid = validator.settings.validate.call(validator, isValid, inputs, flag);
        }
        
        if (isValid) {
          validator.submitButtons.prop('disabled', false).removeClass('disabled');
        } else {
          validator.submitButtons.prop('disabled', true).addClass('disabled');
        }
        
        if (!isValid) {
          validator.result = false;
        }
      }

      if (this.timeout) {
        clearTimeout(this.timeout);
      }

      if (flag === 'delay') {
        this.timeout = setTimeout(validate, 250);
      } else {
        validate();
      }
    }
  }
});

})(jQuery);
