// $Revision$

Ensembl.Panel.SpeciesList = Ensembl.Panel.extend({  
  init: function () {
    this.base();
    
    var reorder    = $('.reorder_species', this.el);
    var full       = $('.full_species', this.el);
    var favourites = $('.favourites', this.el);
    var container  = $('.species_list_container', this.el);
    var dropdown   = $('.dropdown_redirect',this.el);
    
    if (!reorder.length || !full.length || !favourites.length) {
      return;
    }
    
    $('.toggle_link', this.el).on('click', function () {
      reorder.toggle();
      full.toggle();
    });
    
    $('.favourites, .species', this.el).sortable({
      connectWith: '.list',
      containment: this.el,
      stop: function () {
        $.ajax({
          url: '/Account/Favourites/Save',
          data: { favourites: favourites.sortable('toArray').join(',').replace(/(favourite|species)-/g, '') },
          dataType: 'json',
          success: function (data) {
            container.html(data.list);
            dropdown.html(data.dropdown);
          }
        });
      }
    });
    
    $('select.dropdown_redirect', this.el).on('change', function () {
      Ensembl.redirect(this.value);
    });
  }
});
