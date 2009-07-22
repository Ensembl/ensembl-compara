// $Revision$

Ensembl.Panel.SearchBox = Ensembl.Panel.extend({
  init: function () {
    var myself = this;
    
    this.base();
    
    this.elLk.search  = $('table.search', this.el);
    this.elLk.img = $('.search_image', this.elLk.search);
    this.elLk.sites = $('.sites', this.elLk.search);
    this.elLk.siteInput = $('input', this.elLk.sites);
    this.elLk.menu = $('.site_menu', this.el);
    
    var search = Ensembl.cookie.get('ENSEMBL_SEARCH');
    
    $('dt', this.elLk.menu).click(function () {
      var name = this.id.substr(3);
      
      myself.elLk.menu.hide();
      myself.elLk.img.attr('src', '/i/search/' + name + '.gif');
      myself.elLk.siteInput.val(name);
      
      Ensembl.cookie.set('ENSEMBL_SEARCH', name);
    });
    
    this.elLk.sites.click(function () {
      myself.elLk.menu.css({ left: myself.elLk.search.offset().left - 2, top: myself.elLk.search.height() }).toggle();
    });
    
    if (search) {
      this.elLk.img.attr('src', '/i/search/' + search + '.gif');
      this.elLk.siteInput.val(search);
    }
  }
});
