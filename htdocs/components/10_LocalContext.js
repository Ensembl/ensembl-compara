// $Revision$

// Left menu panel - both on the main page and the popup config-type box
Ensembl.Panel.LocalContext = Ensembl.Panel.extend({
  init: function () {    
    this.base();
    
    this.elLk.links = $('ul.local_context li', this.el);
    
    $('img.toggle', this.elLk.links).bind('click', function () {
      var li  = $(this).parent();
      
      li.toggleClass('closed');
      
      this.src = this.src.replace(/closed|open/, li.hasClass('closed') ? 'closed' : 'open');
      
      li = null;
      
      return false;
    });
  }
});
