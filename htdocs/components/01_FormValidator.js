// $Revision$

Ensembl.FormValidator = {
  colours: {
    required: '#fec',
    optional: '#fff',
    error:    '#fcc',
    valid:    '#cfc'
  },
  
  trim: function (s) { 
    return s.replace(/^(\s+)?(.*\S)(\s+)?$/, '$2'); 
  },
  
  isInt:   function (s) { return /^[-+]?\d+$/.test(s); },
  isFloat: function (s) { return /^[-+]?(\d+\.\d+|\d+\.?|\.\d+)?([Ee][+-]?\d+)?$/.test(s); },
  isEmail: function (s) { return /^[^@]+@[^@.:]+[:.][^@]+$/.test(s); },
  isURL:   function (s) { return /^https?:\/\/\w.*$/.test(s); },
  isPass:  function (s) { return /^\S{6,32}$/.test(s); },
  isCode:  function (s) { return /^\S+$/.test(s); },
  isAlpha: function (s) { return /^\w+$/.test(s); },
  isHTML:  function (s) { return !Ensembl.XHTMLValidator.validate(s); },
  
  valid: function (el, s) {
    if (el.is('select')) {
      return true;
    }
    
    var cl = el.attr('className').replace(/.*\b_(\w+)\b.*/, '$1');
    var max = el.attr('className').match(/\bmax_(\d+)\b/);
    
    switch (cl) {
      case 'int'        : return this.isInt(s);
      case 'float'      : return this.isFloat(s);
      case 'email'      : return this.isEmail(s);
      case 'url'        : return this.isURL(s);
      case 'password'   : return this.isPass(s);
      case 'code'       : return this.isCode(s);
      case 'alpha'      : return this.isAlpha(s);
      case 'html'       : return this.isHTML(s);
      case 'age'        : return this.isInt(s)   && parseInt(s)   >= 0 && parseInt(s) <= 150;
      case 'posint'     : return this.isInt(s)   && parseInt(s)   >  0;
      case 'nonnegint'  : return this.isInt(s)   && parseInt(s)   >= 0 && (max == null || parseInt(s) <= max[1]);
      case 'posfloat'   : return this.isFloat(s) && parseFloat(s) >  0;
      case 'nonnegfloat': return this.isFloat(s) && parseFloat(s) >= 0;
      default           : return true;
    }
  },
  
  check: function (el) {
    var required = el.hasClass('required');
    
    if (!required && !el.hasClass('optional')) {
      return;
    }
    
    var value = this.trim(el.val());
    var colour = (value === '') ? (required ? this.colours.required : this.colours.optional) : (this.valid(el, value) ? this.colours.valid : this.colours.error);
    
    el.css('backgroundColor', colour);
  },
  
  submit: function (form) {
    this.getWarnings(form);
    
    // TODO: something nicer than an alert box
    if (this.warnings.length) {
      alert(this.warnings.join('\n') + '\nCorrect ' + (this.warnings.length > 1 ? 'these errors' : 'this error') + ' and try again');
      return false;
    } else {
      if (form.hasClass('confirm') && !confirm('Check the values you entered are correct before continuing')) {
        return false;
      }
    }
    
    return true;
  },
  
  getWarnings: function (form) {
    var myself = this;
    
    this.warnings = []; // Clear old warnings
    
    $(':input', form).each(function () {
      var input = $(this);
      var required = input.hasClass('required');
      
      if (!required && !input.hasClass('optional')) {
        return;
      }
      
      var template;
      var value = myself.trim(input.val());
      
      if (input.is('select')) {
        template = value === '' && required ? 'You must select a value for %s' : '';
      } else {
        if  (value === '') {
          template = required ? 'You must enter a value for %s' : '';
        } else if (input.hasClass('_html')) {         
          var err = Ensembl.XHTMLValidator.validate(value); // Validate as XHTML
          
          template = err ? 'The value of %s is invalid (' + err + ')' : '';
        } else {
          template = myself.valid(input, value) ? '' : 'The value of %s is invalid.'; // Check the types of parameters
        }
      }
      
      if (template) {
        myself.warnings.push(template.replace(/%s/, "'" + input.attr('name') + "'"));
      }
    });
  }
};
