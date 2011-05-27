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
    
    this.live.push(
      $('a.delete_bookmark', this.elLk.content).live('click', function () {
        Ensembl.EventManager.trigger('deleteBookmark', this.href.match(/id=(\d+)\b/)[1]);
      }),
    
      $('form div.select_all input', this.elLk.content).live('click', function () {
        $(this).parents('fieldset').find('input[type=checkbox]').attr('checked', this.checked);
      }),
      
      $('form.wizard input.back', this.elLk.content).live('click', function () {
        $(this).parents('form.wizard').append('<input type="hidden" name="wizard_back" value="1" />').submit();
      })
    );
    
    Ensembl.EventManager.trigger('validateForms', this.el);
    
    this.addSubPanel();
  },
  
  getContent: function (link, url) {
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
        if (e.status !== 0) {
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
    this.elLk.content.html(json.content);
    
    if ($('.panel', this.elLk.content).length > 1) {
      this.elLk.content.removeClass('panel');
    }
    
    this.setSelectAll();
    
    Ensembl.EventManager.trigger('validateForms', this.el);
       
    if ($('.modal_reload', this.el).length) {
      Ensembl.EventManager.trigger('queuePageReload');
    }
    
    this.addSubPanel();
  },
  
  addSubPanel: function () {
    $('.ajax', this.elLk.content).each(function () {
      Ensembl.EventManager.trigger('createPanel', $(this).parents('.js_panel')[0].id, 'Content');
    });
    
    $('.js_panel', this.elLk.content).each(function () {
      var panelType = $('input.panel_type', this).val();
      
      if (panelType) {
        Ensembl.EventManager.trigger('createPanel', this.id, panelType);
      }
    });
  },
  
  setSelectAll: function () {
    $('form div.select_all input', this.elLk.content).attr('checked', function () {
      return $(this).parents('fieldset').find('input[type=checkbox]:not(:checked)').length - 1 <= 0; // -1 for the select_all checkbox itself
    });
  }
});
