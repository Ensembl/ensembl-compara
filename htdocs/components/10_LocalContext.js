// $Revision$

// Left menu panel - both on the main page and the popup config-type box
Ensembl.Panel.LocalContext = Ensembl.Panel.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    this.shareEnabled = false;
    
    $.extend(this, Ensembl.Share);
    
    this.shareInit();
    
    Ensembl.EventManager.register('removeShare',  this, this.removeShare);
    Ensembl.EventManager.register('hashChange',   this, this.removeShare);
    Ensembl.EventManager.register('reloadPage',   this, this.removeShare);
    Ensembl.EventManager.register('ajaxComplete', this, this.shareReady);
    
    if (!this.el.hasClass('modal_nav')) {
      Ensembl.EventManager.register('relocateTools', this, this.relocateTools);
      this.pulseToolButton();
    }
    
    this.elLk.links = $('ul.local_context li', this.el);
    
    $('img.toggle', this.elLk.links).on('click', function () {
      var li  = $(this).parent();
      
      li.toggleClass('closed');
      
      var state = li.hasClass('closed') ? 'closed' : 'open';
      var modal = panel instanceof Ensembl.Panel.ModalContent;
      var code  = (modal ? panel.params.url : window.location.pathname).replace(Ensembl.speciesPath + '/', '').split('/')[0];
      
      $(this).attr('src', function (i, src) { return src.replace(/closed|open/, state); });
      
      $.ajax({
        url: '/Ajax/nav_config',
        data: {
          code:  code,
          menu:  this.className.replace(/toggle|\s/g, ''),
          state: state === 'closed' ^ li.hasClass('default_closed') ? 1 : 0
        }
      });
      
      li = null;
      
      return false;
    });

    this.el.find('._ht').helptip();
  },
  
  relocateTools: function (tools) {
    var toolButtons = $('.tool_buttons', this.el);
    
    tools.each(function () {
      var a        = $(this).find('a')[0];
      var existing = a ? $('.additional .' + a.className.replace(' ', '.'), toolButtons) : [];
      
      if (existing.length) {
        existing.replaceWith(a);
      } else {
        $(this).children().addClass('additional').appendTo(toolButtons).not('.hidden').show();
      }
      
      a = existing = null;
    }).remove();
    
    $('a.seq_blast', toolButtons).on('click', function () {
      $('form.seq_blast', toolButtons).submit();
      return false;
    });
    
    this.pulseToolButton();
    
    tools = null;
  },
  
  pulseToolButton: function () {
    $('.tool_buttons a.pulse:not(.pulsing)', this.el).one('click', function () {
      clearInterval($(this).stop().removeClass('pulse').css({ backgroundColor: '', color: '' }).data('interval'));
    }).addClass('pulsing').each(function () {
      var pulse = $(this).data({
        dark    : false,
        interval: setInterval(function () {
          var data = pulse.data();
          pulse.toggleClass('pulse', !data.dark, 1000);
          data.dark = !data.dark;
        }, 1000)
      });
    });
  },
  
  shareReady: function () {
    var panel = this;
    
    this.shareOptions.species = {};
    
    $.each(Ensembl.PanelManager.getPanels('ImageMap'), function () {
      panel.shareOptions.species[this.id] = this.getSpecies();
    });
    
    this.shareEnabled = true;
    
    if (this.shareWaiting) {
      this.share(this.elLk.shareLink[0].href, this.elLk.shareLink[0]);
    }
    
     Ensembl.EventManager.unregister('ajaxLoaded', this);
  }
});
