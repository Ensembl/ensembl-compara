Ensembl.Panel.ModalContent = Ensembl.Panel.LocalContext.extend({
  constructor: function (id) {
    this.base(id);
    
    Ensembl.EventManager.register('getModalContent', this, this.getContent);
    Ensembl.EventManager.register('modalFormSubmit', this, this.formSubmit);
  },
  
  init: function () {
    var myself = this;
    
    this.activeLink = false;
    
    this.base();
    
    this.elLk.content = $('.modal_wrapper', this.el);
    
    if (Ensembl.ajax == 'enabled') {
      $('a', this.elLk.links).click(function () {
        var link = $(this).parent();
        
        if (!link.hasClass('active')) {
          myself.elLk.links.removeClass('active');
          myself.getContent(link.addClass('active'), this.href);
        }
        
        link = null;
        
        return false;
      });
    }
    
    Ensembl.EventManager.trigger('validateForms', this.el);
  },
  
  getContent: function (link, url, failures) {
    var myself = this;
    
    this.elLk.content.html('<div class="spinner">Loading Content</div>').addClass('panel');
    
    $.ajax({
      url: url,
      dataType: 'json',
      success: function (json) {
        // Avoid race conditions if the user has clicked another nav link while waiting for content to load
        if (link.hasClass('active')) {
          myself.updateContent(json);
        }
      },
      error: function (e) {
        failures = failures || 1;
        
        if (e.status != 500 && failures < 3) {
          setTimeout(function () { myself.getContent(link, url, ++failures); }, 2000);
        } else {
          myself.elLk.content.html('<p class="ajax_error">Failure: The resource failed to load');
        }
      }
    });
  },
  
  formSubmit: function (form) {
    var myself = this;
    
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
      if (Ensembl.ajax == 'enabled') {
        $.ajax({
          url: form.attr('action'),
          type: form.attr('method'),
          data: data,
          dataType: 'json',
          success: function (json) {
            if (json.success === true) {
              Ensembl.EventManager.trigger('reloadPage');
            } else if (form.is(':visible')) {
              myself.updateContent(json);
            }
          },
          error: function (e) {
            myself.elLk.content.html('<p class="ajax_error">Failure: the resource failed to load</p>');
          }
        });
      }
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
