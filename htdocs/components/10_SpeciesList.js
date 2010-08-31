// $Revision$

Ensembl.Panel.SpeciesList = Ensembl.Panel.extend({  
  init: function () {
    this.base();
    
    var reorder    = $('.reorder_species', this.el);
    var full       = $('.full_species', this.el);
    var favourites = $('.favourites', this.el);
    var container  = $('.species_list_container', this.el);
    
    if (!reorder.length || !full.length || !favourites.length) {
      return;
    }
    
    $('.toggle_link', this.el).bind('click', function () {
      reorder.toggle();
      full.toggle();
    });
    
    $('.favourites, .species', this.el).sortable({
      connectWith: '.list',
      containment: this.el,
      stop: function () {
        $.ajax({
          url: '/Account/SaveFavourites',
          data: { favourites: favourites.sortable('toArray').join(',').replace(/(favourite|species)-/g, '') },
          dataType: 'html',
          success: function (html) {
            container.html(html);
          }
        });
      }
    });
    
    $('select.dropdown_redirect', this.el).bind('change', function () {
      Ensembl.redirect(this.value);
      return true;
    });
  }
});
