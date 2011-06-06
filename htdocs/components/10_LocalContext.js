// $Revision$

// Left menu panel - both on the main page and the popup config-type box
Ensembl.Panel.LocalContext = Ensembl.Panel.extend({
  init: function () {    
    this.base();
    
    this.elLk.links = $('ul.local_context li', this.el).each(function () {
      var li = $(this);
      
      if (!$('ul', li).length) {
        li.removeClass('open closed').children('img.toggle').attr('src', '/i/leaf.gif').removeClass('toggle');
      }
      
      li.addClass(li.next().length ? '' : 'last');
      
      li = null;
    });
    
    $('img.toggle', this.el).bind('click', function () {
      var li = $(this).parent(); 
      
      li.toggleClass('open closed');
      
      this.src = '/i/' + (li.hasClass('closed') ? 'closed' : 'open') + '.gif';
      
      li = null;
      
      return false;
    });
  }
});
