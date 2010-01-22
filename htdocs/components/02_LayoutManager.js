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
    Ensembl.EventManager.register('relocateTools', this, this.relocateTools);
    
    $('#local-tools > p').show();
    
    $('.modal_link').show().live('click', function () {
      Ensembl.EventManager.trigger('modalOpen', this);
      return false;
    });
    
    $('.popup').live('click', function () {
      if (window.name.match(/^popup_/)) {
        return true;
      }
      
      window.open(this.href, 'popup_' + window.name, 'width=950,height=500,resizable,scrollbars');
      return false;
    });
    
    $('a[rel="external"]').live('click', function () { 
      this.target = '_blank';
    });
    
    $('form.check').validate().live('submit', function () {
      var form = $(this);
      var rtn = form.parents('#modal_panel').length ? Ensembl.EventManager.trigger('modalFormSubmit', form) : true;      
      form = null;
      return rtn;
    });
    
    // Close modal window if the escape key is pressed
    $(document).bind({
      keyup: function (event) {
        if (event.keyCode == 27) {
          Ensembl.EventManager.trigger('modalClose', true);
        }
      },
      mouseup: function (e) {
        Ensembl.EventManager.trigger('dragStop', e);
      }
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
      Ensembl.redirect();
    }
  },
  
  validateForms: function (context) {
    $('form.check', context).validate();
  },
  
  makeZMenu: function (id, params) {
    $('<table class="zmenu" id="' + id + '" style="display:none">' +
      '  <thead>' + 
      '    <tr><th class="caption" colspan="2"><span class="close">X</span><span class="title"></span></th></tr>' +
      '  </thead>' + 
      '  <tbody></tbody>' + 
      '</table>').draggable({ handle: 'thead' }).appendTo('body');
    
    Ensembl.EventManager.trigger('addPanel', id, 'ZMenu', undefined, undefined, params, 'showExistingZMenu');
  },
  
  relocateTools: function (tools) {
    var localTools = $('#local-tools');
    
    tools.each(function () {
      localTools.append($(this).children().addClass('additional')).children().show();
    }).remove();
    
    $('a.seq_blast', localTools).click(function () {
      $('form.seq_blast', localTools).submit();
      return false;
    });
  }
});

