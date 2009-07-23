// $Revision$

// Left menu panel - both on the main page and the popup config-type box
Ensembl.Panel.LocalContext = Ensembl.Panel.extend({
  init: function () {    
    this.base();
    
    this.elLk.links = $('dl.local_context dd', this.el);
    
    this.elLk.links.each(function () {
      var dd = $(this);
      var dls = $('dl', dd).length;
      var name = 'leaf';
      var cl;
      
      if (dd.hasClass('open')) {
        if (dls > 0) {
          name = 'open';
        } else {
          dd.removeClass('open');
        }
      }
      
      if (dd.hasClass('closed')) {
        if (dls > 0) {
          dd.toggleClass('_closed');
          name = 'closed';
        }
        
        dd.removeClass('closed');
      }
      
      cl = name == 'leaf' ? '' : 'class="toggle"';
      
      dd.prepend('<img src="/i/' + name + '.gif" ' + cl + ' />').addClass(dd.next().length ? 'notl' : 'last');
      
      dd = null;
    });
    
    $('img.toggle', this.el).click(function () {
      var p = $(this).parent(); 
      
      p.toggleClass('open').toggleClass('_closed');
      
      this.src = '/i/' + (p.hasClass('_closed') ? 'closed' : 'open') + '.gif';
      
      p = null;
    });
  }
});
