// $Revision$

Ensembl.Panel.ModalContent = Ensembl.Panel.LocalContext.extend({
  constructor: function (id) {
    this.base(id);
    
    Ensembl.EventManager.register('modalFormSubmit', this, this.formSubmit);
  },
  
  init: function () {
    var myself = this;
    
    this.activeLink = false;
    
    this.base();
    
    this.elLk.content = $('.modal_wrapper', this.el);
    
    $('a', this.elLk.links).click(function () {
      if (!$(this).hasClass('disabled')) {
        var link = $(this).parent();
        
        if (!link.hasClass('active')) {
          myself.elLk.links.removeClass('active');
          myself.getContent(link.addClass('active'), this.href);
        }
        
        link = null;
      }
      
      return false;
    });
    
    $('form td.select_all input', this.elLk.content).click(function () {
      $(this).parents('fieldset').find('input[type=checkbox]').attr('checked', this.checked);
    }).each(function () {
      $(this).attr('checked', !$(this).parents('fieldset').find('input[type=checkbox]:not(:checked)').not(this).length);
    });
    
    $('form.wizard input.back', this.elLk.content).live('click', function () {
      $(this).parents('form.wizard').append('<input type="hidden" name="wizard_back" value="1" />').submit();
    });
    
    Ensembl.EventManager.trigger('validateForms', this.el);
    
    if ($('.ajax', this.elLk.content).length) {
      var panel = $('.ajax', this.elLk.content).parents('.js_panel');
      Ensembl.EventManager.trigger('createPanel', panel.attr('id'), 'Content');
      panel = null;
    }
  },
  
  getContent: function (link, url, failures) {
    this.elLk.content.html('<div class="spinner">Loading Content</div>').addClass('panel');
    
    $.ajax({
      url: url,
      dataType: 'json',
      context: this,
      success: function (json) {
        if (json.redirectURL) {
          return this.getContent(link, json.redirectURL);
        }
        
        // Avoid race conditions if the user has clicked another nav link while waiting for content to load
        if (typeof link == 'undefined' || link.hasClass('active')) {
          this.updateContent(json);
        }
      },
      error: function (e) {
        failures = failures || 1;
        
        if (e.status != 500 && failures < 3) {
          var myself = this;
          setTimeout(function () { myself.getContent(link, url, ++failures); }, 2000);
        } else {
          this.elLk.content.html('<p class="ajax_error">Failure: The resource failed to load</p>');
        }
      }
    });
  },
  
  formSubmit: function (form) {
    if (!form.parents('#' + this.id).length) {
      return false;
    }
    
    if (form.hasClass('upload')) {
      return true;
    }
    
    var data = form.serialize();
    
    if (form.hasClass('export')) {
      $('input.input-checkbox', form).each(function () {
        // overwrite the checkbox with a hidden input with the value of "no" so that we know which boxes have been deselected
        // TODO: rewrite perl so that this isn't necessary
        if (this.checked === false) {
          data += "&" + this.name + "=no";
        }
      });
    }
    
    if (Ensembl.FormValidator.submit(form)) {
      this.elLk.content.html('<div class="spinner">Loading Content</div>');
      
      $.ajax({
        url: form.attr('action'),
        type: form.attr('method'),
        data: data,
        dataType: 'json',
        context: this,
        success: function (json) {
          if (json.redirectURL) {
            return this.getContent(undefined, json.redirectURL);
          }
          
          if (json.success === true) {
            Ensembl.EventManager.trigger('reloadPage');
          } else if ($(this.el).is(':visible')) {
            this.updateContent(json);
          }
        },
        error: function (e) {
          this.elLk.content.html('<p class="ajax_error">Failure: the resource failed to load</p>');
        }
      });
    }
    
    return false;
  },
  
  updateContent: function (json) {    
    this.elLk.content.html(json.content);
    
    if ($('.panel', this.elLk.content).length > 1) {
      this.elLk.content.removeClass('panel');
    }
    
    Ensembl.EventManager.trigger('validateForms', this.el);
       
    if ($('.modal_reload', this.el).length) {
      Ensembl.EventManager.trigger('queuePageReload');
    }
  }
});
