// $Revision$

Ensembl.Panel.SearchBox = Ensembl.Panel.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    this.elLk.img       = $('.search_image', this.el);
    this.elLk.sites     = $('.sites', this.el);
    this.elLk.siteInput = $('input', this.elLk.sites);
    this.elLk.menu      = $('.site_menu', this.el);
    this.elLk.input     = $('.query', this.el);
    
    this.label = this.elLk.input[0].defaultValue;
    
    this.updateSearch(Ensembl.cookie.get('ENSEMBL_SEARCH'));
    
    if (this.label !== this.elLk.input.val()) {
      this.elLk.input.removeClass('inactive');
    }
    
    this.elLk.input.on({
      focus: function() {
        if (panel.label === this.value) {
          $(this).removeClass('inactive').val('');
        }
      },
      blur: function() {
        if (!this.value) {
          $(this).addClass('inactive').val(panel.label);
        }
      }
    });

    $('div', this.elLk.menu).on('click', function () {
      var name = this.className;
      
      panel.updateSearch(name);
      panel.elLk.menu.hide();
      
      Ensembl.cookie.set('ENSEMBL_SEARCH', name);
    });

    this.elLk.sites.on('click', function () {
      panel.elLk.menu.toggle();
    });
    
    $('form', this.el).on('submit', function () {
      if (panel.elLk.input.val() === panel.label || panel.elLk.input.val() === '') {
        return false;
      }
    });
  },
  
  updateSearch: function (type) {
    var label = type ? $('.' + type + ' input', this.elLk.menu).val() : false;
    
    if (label) {
      this.elLk.img.attr('src', '/i/search/' + type + '.gif');
      this.elLk.siteInput.val(type);
      
      if (this.elLk.input.val() === this.label) {
        this.elLk.input.val(label);
      }
      
      this.label = label;
    }
  }
});
