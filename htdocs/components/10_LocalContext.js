// $Revision$

// Left menu panel - both on the main page and the popup config-type box
Ensembl.Panel.LocalContext = Ensembl.Panel.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    this.elLk.links = $('ul.local_context li', this.el);
    
    $('img.toggle', this.elLk.links).bind('click', function () {
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
  }
});
