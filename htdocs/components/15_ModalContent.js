// $Revision$

Ensembl.Panel.ModalContent = Ensembl.Panel.LocalContext.extend({
  constructor: function () {
    this.base.apply(this, arguments);
    
    Ensembl.EventManager.register('modalFormSubmit', this, this.formSubmit);
  },
  
  init: function () {
    var panel = this;
    
    this.activeLink = false;
    
    this.base();
    
    this.elLk.content = $('.modal_wrapper', this.el);
    
    $('a', this.elLk.links).bind('click', function () {
      if (!$(this).hasClass('disabled')) {
        var link = $(this).parent();
        
        if (!link.hasClass('active')) {
          panel.elLk.links.removeClass('active');
          panel.getContent(link.addClass('active'), this.href);
        }
        
        link = null;
      }
      
      return false;
    });
    
    $('form td.select_all input', this.elLk.content).live('click', function () {
      $(this).parents('fieldset').find('input[type=checkbox]').attr('checked', this.checked);
    }).each(function () {
      $(this).attr('checked', !$(this).parents('fieldset').find('input[type=checkbox]:not(:checked)').not(this).length);
    });
    
    $('fieldset.matrix input.select_all_column, fieldset.matrix input.select_all_row', this.elLk.content).live('click', function () {
      $(this).parents('fieldset').find('input.' + $(this).attr('name')).attr('checked', this.checked);
    }).each(function () {
      $(this).attr('checked', !$(this).parents('fieldset').find('input.' + this.name + ':not(:checked)').length);
    });
    
    $('form.wizard input.back', this.elLk.content).live('click', function () {
      $(this).parents('form.wizard').append('<input type="hidden" name="wizard_back" value="1" />').submit();
    });
    
    Ensembl.EventManager.trigger('validateForms', this.el);
    
    if ($('.ajax', this.elLk.content).length) {
      Ensembl.EventManager.trigger('createPanel', $('.ajax', this.elLk.content).parents('.js_panel')[0].id, 'Content');
    }
  },
  
  getContent: function (link, url, failures) {
    this.elLk.content.html('<div class="spinner">Loading Content</div>').addClass('panel');
    
    $.ajax({
      url: Ensembl.replaceTimestamp(url),
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
          var panel = this;
          setTimeout(function () { panel.getContent(link, url, ++failures); }, 2000);
        } else {
          this.elLk.content.html('<p class="ajax_error">Failure: The resource failed to load</p>');
        }
      }
    });
  },
  
  formSubmit: function (form, data) {
    if (!form.parents('#' + this.id).length) {
      return false;
    }
    
    if (form.hasClass('upload')) {
      return true;
    }
    
    data = data || form.serialize();
    
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
    
    return false;
  },
  
  updateContent: function (json) {    
    this.elLk.content.html(json.content);
    
    if ($('.panel', this.elLk.content).length > 1) {
      this.elLk.content.removeClass('panel');
    }
    
    $('form td.select_all input', this.elLk.content).each(function () {
      $(this).attr('checked', !$(this).parents('fieldset').find('input[type=checkbox]:not(:checked)').not(this).length);
    });
    
    $('fieldset.matrix input.select_all_column, fieldset.matrix input.select_all_row', this.elLk.content).each(function () {
      $(this).attr('checked', !$(this).parents('fieldset').find('input.' + this.name + ':not(:checked)').length);
    });
    
    Ensembl.EventManager.trigger('validateForms', this.el);
       
    if ($('.modal_reload', this.el).length) {
      Ensembl.EventManager.trigger('queuePageReload');
    }
  }
});
