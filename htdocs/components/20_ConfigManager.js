// $Revision$

Ensembl.Panel.ConfigManager = Ensembl.Panel.ModalContent.extend({
  constructor: function (id, params) {
    this.base(id, params);
  },

  init: function () {
    var panel = this;
    
    this.base();
    
    this.editing = false;
    
    Ensembl.EventManager.register('modalPanelResize', panel,function() {
      this.el.togglewrap('update');
    });
    
    this.el.on('click', 'a.edit', function (e) {
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
    }).on('click', 'a.add_to_set', function () {
      var tr = $(this).parents('tr');
      
      if (!tr.hasClass('disabled')) {
        tr.toggleClass('added').siblings('.' + (this.rel || '_')).toggleClass('disabled');
      }
      
      $(this).attr('title', tr.hasClass('added') ? 'Remove from set' : 'Add to set');
      
      tr = null;
      
      return false;
    }).on('click', 'a.create_set', function () {
      var els  = $('.sets > div, .edit_set', panel.el).toggle();
      var func = $(this).children().toggle().filter(':visible').attr('class') === 'cancel' ? 'show' : 'hide';
      
      $('form', panel.el).find('fieldset > div')[func]().find('[name=name], [name=description]').val('').removeClass('valid');
      
      if (func === 'show') {
        els.togglewrap('update');
        panel.editing = false;
      }
      
      els = null;
      
      return false;
    }).on('click', 'a.edit_record', function () {
      var els   = $('.edit_set, form .save_button, a.create_set', panel.el).toggle();
      var show  = $('form', panel.el).toggleClass('edit_configs').find('[name=name]').val('editing').end().hasClass('edit_configs');
      var group = $(this).parents('.config_group');
      
      if (group.length) {
        $('.config_group', panel.el).not(group).toggle();
      }
      
      if (show) {
        els.togglewrap('update');
        panel.editing = this.rel;
      }
      
      $(this).parents('tr').siblings().toggle().end().find('ul li').each(function () {
        $('input.update[value=' + this.className + ']', this.el).siblings('a.add_to_set').trigger('click');
      });
      
      els = group = null;
      
      return false;
    });    
  },
  
  initialize: function () {
    this.base();
    
    if (this.dataTables) {
      $.each(this.dataTables, function () {
        $(this.fnSettings().nTableWrapper).show();
      });
    }
    
    tr = null;
  },
    
  saveEdit: function (input, value) {
    var param    = input.attr('name');
    var save     = input.siblings('a.save');
    var configId = save.attr('rel');
    
    input.parent().togglewrap('update');
    
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
    var panel  = this;
    var bg     = tr.css('backgroundColor');
    var height = tr.height() + 'px';
    
    tr.siblings('.active').stop(true, true).removeClass('active').css('backgroundColor', '')
      .find('.config_used').stop(true, true).hide();
    
    tr.addClass('active').delay(1000).animate({ backgroundColor: bg }, 1000, function () { $(this).removeClass('active').css('backgroundColor', ''); })
      .find('.config_used').css({ height: height, lineHeight: height, width: tr.width() - 1, display: 'block' }).delay(1000).fadeOut(500);
    
    $.each(components.split(' '), function (i, component) {
      if (Ensembl.PanelManager.panels[component]) {
        Ensembl.EventManager.trigger('queuePageReload', component, true);
        Ensembl.EventManager.trigger('activateConfig',  component);
      }
    });
    
    tr = null;
  },
  
  deleteRecord: function (tr, configId) {
    tr.parents('table').dataTable().fnDeleteRow(tr[0]);
    
    Ensembl.EventManager.trigger('updateSavedConfig', { deleted: [ configId ] });
    
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
