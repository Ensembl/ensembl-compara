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
    
    this.setSelectAll();
    
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
    
    $('a.delete_bookmark', this.elLk.content).live('click', function () {
      Ensembl.EventManager.trigger('deleteBookmark', this.href.match(/id=(\d+)\b/)[1]);
    });
    
    $('form div.select_all input', this.elLk.content).live('click', function () {
      $(this).parents('fieldset').find('input[type=checkbox]').attr('checked', this.checked);
    });
    
    $('fieldset.matrix input.select_all_column, fieldset.matrix input.select_all_row', this.elLk.content).live('click', function () {
      $(this).parents('fieldset').find('input.' + this.name).attr('checked', this.checked);
    });
    
    $('fieldset.matrix select.select_all_column, fieldset.matrix select.select_all_row', this.elLk.content).live('change', function () {
      var cls    = this.value;
      var inputs = $(this).parents('fieldset').find('input.' + this.name);
      
      switch (cls) {
        case ''     : break;
        case 'none' : inputs.attr('checked', false); break;
        case 'all'  : inputs.attr('checked', 'checked'); break;
        default     : inputs.filter('.' + cls).attr('checked', 'checked').end().not('.' + cls).attr('checked', false);
      }
      
      inputs = null;
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
        if (typeof link === 'undefined' || link.hasClass('active')) {
          this.updateContent(json);
        }
      },
      error: function (e) {
        failures = failures || 1;
        
        if (e.status !== 500 && failures < 3) {
          var panel = this;
          setTimeout(function () { panel.getContent(link, url, ++failures); }, 2000);
        } else if (e.status !== 0) {
          this.elLk.content.html('<p class="ajax_error>Sorry, the page request failed to load.</p>');
        }
      }
    });
  },
  
  formSubmit: function (form, data) {
    if (!form.parents('#' + this.id).length) {
      return undefined;
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
        if (e.status !== 0) {
          this.elLk.content.html('<p class="ajax_error">Sorry, the page request failed to load.</p>');
        }
      }
    });
    
    return false;
  },
  
  updateContent: function (json) {    
    this.elLk.content.replaceWith(json.content);
    this.elLk.content = $('.modal_wrapper', this.el);
    
    if ($('.panel', this.elLk.content).length > 1) {
      this.elLk.content.removeClass('panel');
    }
    
    if ($('.ajax', this.elLk.content).length) {
      Ensembl.EventManager.trigger('createPanel', $('.ajax', this.elLk.content).parents('.js_panel')[0].id, 'Content');
    }
    
    this.setSelectAll();
    
    Ensembl.EventManager.trigger('validateForms', this.el);
       
    if ($('.modal_reload', this.el).length) {
      Ensembl.EventManager.trigger('queuePageReload');
    }
  },
  
  setSelectAll: function () {
    $('form div.select_all input', this.elLk.content).attr('checked', function () {
      return !$(this).parents('fieldset').find('input[type=checkbox]:not(:checked)').not(this).length;
    });
    
    $('fieldset.matrix input.select_all_column, fieldset.matrix input.select_all_row', this.elLk.content).attr('checked', function () {
      return !$(this).parents('fieldset').find('input.' + this.name + ':not(:checked)').length;
    });
    
    $('fieldset.matrix select.select_all_column, fieldset.matrix select.select_all_row', this.elLk.content).each(function () {
      var inputs  = $(this).parents('fieldset').find('input.' + this.name);
      var checked = inputs.filter(':checked');
      var val, i, filtered;
      
      if (!checked.length) {
        this.value = 'none';
      } else if (inputs.length === checked.length) {
        this.value = 'all';
      } else {
        i = this.options.length;
        
        while (i--) {
          val = this.options[i].value;
          
          if (val && !val.match(/^(all|none)$/)) {
            filtered = inputs.filter('.' + val);
            
            if (filtered.length === checked.length) {
              this.value = val;
              break;
            }
          }
        }
      }
      
      inputs   = null;
      checked  = null;
      filtered = null;
    });
  }
});
