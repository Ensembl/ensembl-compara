// $Revision$

// Left menu panel - both on the main page and the popup config-type box
Ensembl.Panel.LocalContext = Ensembl.Panel.extend({
  init: function () {    
    this.base();
    
    this.elLk.links = $('ul.local_context li', this.el);
    
    $('img.toggle', this.elLk.links).bind('click', function () {
      var li = $(this).parent(); 
      
      li.toggleClass('open closed');
      
      this.src = '/i/' + (li.hasClass('closed') ? 'closed' : 'open') + '.gif';
      
      li = null;
      
      return false;
    });
  }
});
