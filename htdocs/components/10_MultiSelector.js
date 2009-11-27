// $Revision$

Ensembl.Panel.MultiSelector = Ensembl.Panel.extend({
  constructor: function (id) {
    this.base(id);
    
    Ensembl.EventManager.register('updateConfiguration', this, this.updateSpecies);
    Ensembl.EventManager.register('modalPanelResize', this, this.style);
  },
  
  init: function () {
    var myself = this;
    
    this.base();
    
    this.initialSpecies = '';
    this.species = [];
    
    this.elLk.content = $('.modal_wrapper', this.el);
    this.elLk.list = $('.multi_selector_list', this.elLk.content);
    
    var ul = $('ul', this.elLk.list);
    var spans = $('span', ul)
    
    this.elLk.spans = spans.filter(':not(.switch)');
    this.elLk.form = $('form', this.elLk.content);
    this.elLk.included = ul.filter('.included');
    this.elLk.excluded = ul.filter('.excluded');
    
    this.setSpecies(true);
    
    this.elLk.included.sortable({
      containment: myself.elLk.included.parent(),
      stop: function () { myself.setSpecies(); }
    });
    
    this.buttonWidth = spans.filter('.switch').click(function () {
      var li = $(this).parent();
      
      if (li.parent().hasClass('included')) {
        var excluded = $('li', myself.elLk.excluded);
        var i = excluded.length;

        while (i--) {
          if ($(excluded[i]).text() < li.text()) {
            $(excluded[i]).after(li);
            break;
          }
        }
        
        // species to be added is closer to the start of the alphabet than anything in the excluded list
        if (i == -1) {
          myself.elLk.excluded.prepend(li);
        }
        
        myself.setSpecies();
        
        excluded = null;
      } else {
        myself.elLk.included.append(li);
        myself.species.push(li.attr('className'));
      }
      
      li = null;
    }).width();
    
    this.style();
    
    ul = null;
  },
  
  style: function () {
    var width = 0;
    
    this.elLk.spans.each(function () {
      var w = $(this).width();

      if (w > width) {
        width = w;
      }
    });
    
    this.elLk.list.width('');
    this.elLk.list.width(this.elLk.list.width() < width + this.buttonWidth ? '100%' : '');
  },
  
  setSpecies: function (init) {
    this.species = $.map($('li', this.elLk.included), function (li, i) {
      return li.className;
    });
    
    if (init === true) {
      this.initialSpecies = this.species.join(',');
    }
  },
  
  updateSpecies: function () {
    var existingSpecies = {};
    var i, j;
    
    for (i in Ensembl.multiSpecies) {
      existingSpecies[Ensembl.multiSpecies[i].s] = parseInt(i);
    }
    
    var params = [];
    
    for (i = 0; i < this.species.length; i++) {
      j = existingSpecies[this.species[i]];
      
      if (typeof j != 'undefined') {
        $.each(['r', 'g', 's'], function () {
          if (Ensembl.multiSpecies[j][this]) {
            params.push(this + (i + 1) + '=' + Ensembl.multiSpecies[j][this]);
          }
        });
      } else {
        params.push('s' + (i + 1) + '=' + this.species[i]);
      }
    }
    
    if (this.species.join(',') != this.initialSpecies) {
      Ensembl.redirect(this.elLk.form.attr('action') + '?' + Ensembl.cleanURL(this.elLk.form.serialize() + ';' + params.join(';')));
    }
    
    return true;
  }
});