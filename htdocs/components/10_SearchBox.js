// $Revision$

Ensembl.Panel.SearchBox = Ensembl.Panel.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    this.elLk.search    = $('table.search', this.el);
    this.elLk.img       = $('.search_image', this.elLk.search);
    this.elLk.sites     = $('.sites', this.elLk.search);
    this.elLk.siteInput = $('input', this.elLk.sites);
    this.elLk.menu      = $('.site_menu', this.el);
    
    var search = Ensembl.cookie.get('ENSEMBL_SEARCH');
    
    $('dt', this.elLk.menu).bind('click', function () {
      var name = this.id.substr(3);
      
      panel.elLk.menu.hide();
      panel.elLk.img.attr('src', '/i/search/' + name + '.gif');
      panel.elLk.siteInput.val(name);
      
      Ensembl.cookie.set('ENSEMBL_SEARCH', name);
    });
    
    this.elLk.sites.bind('click', function () {
      panel.elLk.menu.toggle();
    });
    
    if (search) {
      this.elLk.img.attr('src', '/i/search/' + search + '.gif');
      this.elLk.siteInput.val(search);
    }
  }
});
