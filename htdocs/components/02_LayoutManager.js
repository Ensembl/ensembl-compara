// $Revision$

Ensembl.LayoutManager = new Base();

Ensembl.LayoutManager.extend({
  constructor: null,
  
  /**
   * Creates events on elements outside of the domain of panels
   */
  initialize: function () {
    this.id = 'LayoutManager';
    
    Ensembl.EventManager.register('reloadPage', this, this.reloadPage);
    Ensembl.EventManager.register('validateForms', this, this.validateForms);
    Ensembl.EventManager.register('makeZMenu', this, this.makeZMenu);
    
    $('#local-tools').show();
    
    $('.modal_link').show().live('click', function () {
      // If ajax is not enabled, make popup config window
      // If ajax is enabled, modalOpen is triggered. If it doesn't returns true then there's no ModalContainer panel, so make popup config window
      if (Ensembl.ajax != 'enabled' || !Ensembl.EventManager.trigger('modalOpen', this)) {
        var name = 'cp_' + window.name;
        var w = window.open(this.href, name.replace(/cp_cp_/, 'cp_'), 'width=950,height=500,resizable,scrollbars');
        w.focus();
      }
      
      return false;
    });
    
    $('.popup').live('click', function () {
      var w = window.open(this.href, 'popup_' + window.name, 'width=950,height=500,resizable,scrollbars');
      w.focus();
      
      return false;
    });
    
    $('a[rel="external"]').live('click', function () { 
      this.target = '_blank';
    });
    
    // using livequery plugin because .live doesn't support blur, focus, mouseenter, mouseleave, change or submit in IE
    $('form.check').livequery('submit', function () {
      var form = $(this);
      var rtn = form.parents('#modal_panel').length ? 
                Ensembl.EventManager.trigger('modalFormSubmit', form) : 
                Ensembl.FormValidator.submit(form);
      
      form = null;
      return rtn;
    });
    
    $(':input', 'form.check').live('keyup', function () {
      Ensembl.FormValidator.check($(this));
    }).livequery('change', function () {
      Ensembl.FormValidator.check($(this));
    }).livequery('blur', function () { // IE is stupid, so we need blur as well as change if you select from browser-stored values
      Ensembl.FormValidator.check($(this));
    }).each(function () {
      Ensembl.FormValidator.check($(this));
    });
    
    // For non ajax support - popup window close button
    var close = $('.popup_close');
    
    if (close.length) {
      if ($('input.panel_type[value=Configurator]').length) {
        close.html('Save and close').click(function () {      
          if (Ensembl.EventManager.trigger('updateConfiguration') || window.location.search.match('reset=1')) {
            window.open(Ensembl.replaceTimestamp(this.href), window.name.replace(/^cp_/, '')); // Reload the main page
          }
          
          window.close();
          
          return false;
        });
      } else {
        close.hide();
      }
    }
    
    close = null;
    
    // Close modal window if the escape key is pressed
    $(document).keyup(function (event) {
      if (event.keyCode == 27) {
        Ensembl.EventManager.trigger('modalClose');
      }
    }).mouseup(function (e) {
      Ensembl.EventManager.trigger('dragStop', e);
    });
    
    var userMessage = unescape(Ensembl.cookie.get('user_message'));
    
    if (userMessage) {
      userMessage = userMessage.split('\n');
      
      $('<div class="hint" style="margin: 10px 25%;">' +
        ' <h3><img src="/i/close.gif" alt="Hide hint panel" title="Hide hint panel" />' + userMessage[0] + '</h3>' +
        ' <p>' + userMessage[1] + '</p>' +
        '</div>').prependTo('#main').find('h3 img, a').click(function () {
        $(this).parents('div.hint').remove();
        Ensembl.cookie.set('user_message', '', -1);
      });
    }
  },
  
  reloadPage: function (args) {
    if (typeof args == 'string') {
      Ensembl.EventManager.triggerSpecific('updatePanel', args);
    } else if (typeof args == 'object') {
      for (var i in args) {
        Ensembl.EventManager.triggerSpecific('updatePanel', i);
      }
    } else {
      window.location = Ensembl.replaceTimestamp(window.location.href);
    }
  },
  
  validateForms: function (context) {
    $('form.check', context).find(':input').each(function () {
      Ensembl.FormValidator.check($(this));
    });
  },
  
  makeZMenu: function (id, params) {
    $('<table class="zmenu" id="' + id + '" style="display:none">' +
      '  <thead>' + 
      '    <tr><th class="caption" colspan="2"><span class="close">X</span><span class="title"></span></th></tr>' +
      '  </thead>' + 
      '  <tbody></tbody>' + 
      '</table>').draggable({ handle: 'thead' }).appendTo('body');
    
    Ensembl.EventManager.trigger('addPanel', id, 'ZMenu', undefined, undefined, params, 'showExistingZMenu');
  }
});