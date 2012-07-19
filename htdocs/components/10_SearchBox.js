// $Revision$

Ensembl.Panel.SearchBox = Ensembl.Panel.extend({
  init: function () {
    var panel = this;
    
    this.base();
    
    this.elLk.img       = $('.search_image', this.el);
    this.elLk.sites     = $('.sites', this.el);
    this.elLk.siteInput = $('input', this.elLk.sites);
    this.elLk.menu      = $('.site_menu', this.el);
    this.elLk.inp       = $('.search input[type=text]');
    this.label          = this.elLk.inp[0].defaultValue;

    var search = Ensembl.cookie.get('ENSEMBL_SEARCH');

    this.elLk.inp.bind({
      'focus' : function() {
        if (panel.label == this.value) {
          $(this).removeClass('inactive').val('');
        }
      },
      'blur'  : function() {
        if (this.value == '') {
          $(this).addClass('inactive').val(panel.label);
        }
      }
    });

    $('div', this.elLk.menu).on('click', function () {
      var name  = this.id.substr(3);
      var label = $('input', this).val();
      if (panel.elLk.inp.val() == panel.label) {
        panel.elLk.inp.val(label);
      }
      panel.label = label;
      panel.elLk.menu.hide();
      panel.elLk.img.attr('src', '/i/search/' + name + '.gif');
      panel.elLk.siteInput.val(name);

      Ensembl.cookie.set('ENSEMBL_SEARCH', name);
    });

    this.elLk.sites.on('click', function () {
      panel.elLk.menu.toggle();
    });

    if (search) {
      if ($('#se_' + search).length) {
        this.elLk.img.attr('src', '/i/search/' + search + '.gif');
        this.elLk.siteInput.val(search);
        var label = $('#se_' + search + ' input').val();
        if (this.elLk.inp.val() == this.label) {
          this.elLk.inp.val(label);
        }
        this.label = label;
      }
    }

    if (this.label != this.elLk.inp.val()) {
      this.elLk.inp.removeClass('inactive');
    }
  }
});
