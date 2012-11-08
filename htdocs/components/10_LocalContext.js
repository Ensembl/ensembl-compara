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
  }
});
