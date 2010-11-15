// $Revision$

Ensembl.LayoutManager = new Base();

Ensembl.LayoutManager.extend({
  constructor: null,
  
  /**
   * Creates events on elements outside of the domain of panels
   */
  initialize: function () {
    this.id = 'LayoutManager';
    
    Ensembl.EventManager.register('reloadPage',    this, this.reloadPage);
    Ensembl.EventManager.register('validateForms', this, this.validateForms);
    Ensembl.EventManager.register('makeZMenu',     this, this.makeZMenu);
    Ensembl.EventManager.register('relocateTools', this, this.relocateTools);
    Ensembl.EventManager.register('hashChange',    this, this.hashChange);
    Ensembl.EventManager.register('toggleContent', this, this.toggleContent);
        
    $('#local-tools > p').show();
    
    $('#header a:not(#tabs a)').addClass('constant');
    
    if ((window.location.hash.replace(/^#/, '?') + ';').match(Ensembl.hashRegex)) {
      $('.ajax_load').val(function () {
        return Ensembl.urlFromHash(this.value);
      });
      
      this.hashChange(Ensembl.urlFromHash(window.location.href, true));
    }
        
    $('.modal_link').show().live('click', function () {
      if (Ensembl.EventManager.trigger('modalOpen', this)) {
        return false;
      }
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
    
    this.validateForms(document);
    
    // Close modal window if the escape key is pressed
    $(document).bind({
      keyup: function (event) {
        if (event.keyCode == 27) {
          Ensembl.EventManager.trigger('modalClose', true);
        }
      },
      mouseup: function (e) {
        // only fired on left click
        if (!e.which || e.which == 1) {
          Ensembl.EventManager.trigger('mouseUp', e);
        }
      }
    });
    
    $(window).bind({
      resize: function () {
        Ensembl.EventManager.trigger('windowResize');
      },
      hashchange: function (e) {
        if ((window.location.hash.replace(/^#/, '?') + ';').match(Ensembl.hashRegex)) {
          Ensembl.setCoreParams();
          Ensembl.EventManager.trigger('hashChange', Ensembl.urlFromHash(window.location.href, true));
        }
      }
    });
    
    var userMessage = unescape(Ensembl.cookie.get('user_message'));
    
    if (userMessage) {
      userMessage = userMessage.split('\n');
      
      $([
        '<div class="hint" style="margin: 10px 25%;">',
        ' <h3><img src="/i/close.gif" alt="Hide hint panel" title="Hide hint panel" />', userMessage[0], '</h3>',
        ' <p>', userMessage[1], '</p>',
        '</div>'
      ].join('')).prependTo('#main').find('h3 img, a').click(function () {
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
    $('form.check', context).validate().bind('submit', function () {
      return $(this).parents('#modal_panel').length ? Ensembl.EventManager.trigger('modalFormSubmit', $(this)) : true;
    });
  },
  
  makeZMenu: function (id, params) {
    if (!$('#' + id).length) {
      $([
        '<table class="zmenu" id="' + id + '" style="display:none">',
        '  <thead>', 
        '    <tr><th class="caption" colspan="2"><span class="close">X</span><span class="title"></span></th></tr>',
        '  </thead>', 
        '  <tbody></tbody>',
        '</table>'
      ].join('')).draggable({ handle: 'thead' }).appendTo('body');
    }
    
    Ensembl.EventManager.trigger('addPanel', id, 'ZMenu', undefined, undefined, params, 'showExistingZMenu');
  },
  
  relocateTools: function (tools) {
    var localTools = $('#local-tools');
    
    tools.each(function () {
      $(this).children().addClass('additional').appendTo(localTools).not('.hidden').show();
    }).remove();
    
    $('a.seq_blast', localTools).click(function () {
      $('form.seq_blast', localTools).submit();
      return false;
    });
  },
  
  hashChange: function (r) {
    if (!r) {
      return;
    }
    
    var text = r.split(/\W/);
    text     = text[0] + ': ' + Ensembl.thousandify(text[1]) + '-' + Ensembl.thousandify(text[2]);
    
    $('a:not(.constant)').attr('href', function () {
      var r;
      
      if (this.title == 'UCSC') {
        this.href = this.href.replace(/(&?position=)[^&]+(.?)/, '$1chr' + Ensembl.urlFromHash(this.href, true) + '$2');
      } else if (this.title == 'NCBI') {
        r = Ensembl.urlFromHash(this.href, true).split(/[:-]/);
        this.href = this.href.replace(/(&?CHR=).+&BEG=.+&END=[^&]+(.?)/, '$1' + r[0] + '&BEG=' + r[1] + '&END=' + r[2] + '$2');
      } else {
        return Ensembl.urlFromHash(this.href);
      }
    });
    
    $('input[name=r]', 'form:not(#core_params)').val(r);
    
    $('h2.caption').html(function (i, html) {
      return html.replace(/^(Chromosome ).+/, '$1' + text);
    });
  },
  
  toggleContent: function (rel) {
    $('a.toggle[rel="' + rel + '"]').toggleClass('open closed');
  }
});

