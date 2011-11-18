// $Revision$

Ensembl.Panel.ConfigManager = Ensembl.Panel.ModalContent.extend({
  constructor: function (id, params) {
    this.base(id, params);

    Ensembl.EventManager.register('modalPanelResize', this, this.wrapping);
  },

  init: function () {
    var panel = this;
    
    this.base();
    
    this.editing = false;
    
    this.live.push(      
      $('img.toggle', this.el).live('click', function () {
        this.src = this.src.match(/closed/) ? '/i/open2.gif' : '/i/closed2.gif';
        $(this).siblings('.heightWrap').toggleClass('open');
        return false;
      }),
      
      $('a.edit', this.el).live('click', function (e) {
        e.preventDefault();
        
        $.ajax({
          url: this.href,
          context: this,
          success: function (response) {
            if (panel[response]) {
              panel[response]($(this).parents('tr'), this.rel);
            } else {
              //an error
            }
          },
          error: function () {
            //an error
          }
        });
      }),
      
      $('a.add_to_set', this.el).live('click', function () {
        var tr = $(this).parents('tr');
        
        if (!tr.hasClass('disabled')) {
          tr.toggleClass('added').siblings('.' + (this.rel || '_')).toggleClass('disabled');
        }
        
        $(this).attr('title', tr.hasClass('added') ? 'Remove from set' : 'Add to set');
        
        tr = null;
        
        return false;
      }),
      
      $('a.create_set', this.el).live('click', function () {
        var els  = $('.sets > div, .edit_set', panel.el).toggle();
        var func = $(this).children().toggle().filter(':visible').attr('class') === 'cancel' ? 'show' : 'hide';
        
        $('form', panel.el).find('fieldset > div')[func]().find('[name=name], [name=description]').val('').removeClass('valid');
        
        if (func === 'show') {
          panel.wrapping(els.find('.heightWrap'));
          panel.editing = false;
        }
        
        els = null;
        
        return false;
      }),
      
      $('a.edit_record', this.el).live('click', function () {
        var els   = $('.edit_set, form .save, a.create_set', panel.el).toggle();
        var show  = $('form', panel.el).toggleClass('edit_configs').find('[name=name]').val('editing').end().hasClass('edit_configs');
        var group = $(this).parents('.config_group');
        
        if (group.length) {
          $('.config_group', panel.el).not(group).toggle();
        }
        
        if (show) {
          panel.wrapping(els.find('.heightWrap'));
          panel.editing = this.rel;
        }
        
        $(this).parents('tr').siblings().toggle().end().find('ul li').each(function () {
          $('input.update[value=' + this.className + ']', this.el).siblings('a.add_to_set').trigger('click');
        });
        
        els = group = null;
        
        return false;
      })
    );
    
    this.wrapping();
  },
  
  initialize: function () {
    this.base();
    this.wrapping();
    
    $.each(this.dataTables, function () {
      $(this.fnSettings().nTableWrapper).show();
    });
    
    var tr = $('.sets table tbody tr:first', this.el);
    
    this.elLk.activated = $('p.activated', this.el).css({ width: tr.outerWidth(), height: tr.outerHeight() });
    
    tr = null;
  },
  
  wrapping: function (els) {
    (els || $('.heightWrap', this.el)).each(function () {
      var el   = $(this);
      var open = el.hasClass('open');
      
      if (open) {
        el.removeClass('open');
      }
      
      // check if content is hidden by overflow: hidden
      el.next('img.toggle')[$(this).height() < $(this).children().height() ? 'show' : 'hide']();
      
      if (open) {
        el.addClass('open');
      }
      
      el = null;
    });
    
    els = null;
  },
  
  saveEdit: function (input, value) {
    var param    = input.attr('name');
    var save     = input.siblings('a.save');
    var configId = save.attr('rel');
    
    this.wrapping(input.siblings('.heightWrap'));
    
    $.ajax({
      url: save.attr('href'),
      data: { param: param, value: value },
      success: function (response) {
        if (response === 'success' && param === 'name') {
          Ensembl.EventManager.trigger('updateSavedConfig', { changed: { id: configId, name: value } });
        }
      },
      error: function () {
        //an error
      }
    });
    
    input = save = null;
  },
  
  activateRecord: function (tr, components) {
    var panel    = this;
    var bg       = tr.css('backgroundColor');
    var position = tr.position();
    
    tr.addClass('active').siblings('.active').removeClass('active').css('backgroundColor', '');
    
    clearTimeout(this.elLk.activated.stop(true).delay);
    
    this.elLk.activated.css({ top: position.top, left: position.left, display: 'block', opacity: 1 }).delay = setTimeout(function () {
      tr.animate({ backgroundColor: bg }, 1, function () { $(this).removeClass('active').css('backgroundColor', ''); })
      panel.elLk.activated.fadeOut(1000);
    }, 2000);
    
    $.each(components.split(' '), function (i, component) {
      if (Ensembl.PanelManager.panels[component]) {
        Ensembl.EventManager.trigger('queuePageReload', component, true);
        Ensembl.EventManager.trigger('activateConfig',  component);
      }
    });
  },
  
  deleteRecord: function (tr, configId) {
    tr.parents('table').dataTable().fnDeleteRow(tr[0]);
    
    Ensembl.EventManager.trigger('updateConfig', { deleted: [ configId ] });
    
    tr = null;
  },
  
  removeFromSet: function (tr, configId) {
    tr.find('li.' + configId).remove();
    
    tr = null;
  },
  
  formSubmit: function (form) {
    var data = form.serialize();
    
    if (form.hasClass('edit_sets') && this.editing) {
      data += '&record_id=' + this.editing;
    } else if (form.hasClass('edit_configs') && this.editing) {
      data += '&set_id=' + this.editing;
    }
    
    $('tr.added input.update', this.el).each(function () { data += '&' + this.name + '=' + this.value; });
    
    return this.base(form, data);
  }
});
