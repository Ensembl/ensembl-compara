// $Revision$

Ensembl.Panel.Configurator = Ensembl.Panel.ModalContent.extend({
  constructor: function (id) {
    this.base(id);
    
    Ensembl.EventManager.register('updateConfiguration', this, this.updateConfiguration);
  },
  
  init: function () {
    var myself = this;
    
    this.base();
    
    this.elLk.form = $('form.configuration', this.el);
    this.elLk.search = $('.configuration_search_text', this.el);
    
    this.initialConfig = {};
    this.lastQuery = false;
    
    $.each(this.elLk.form.serializeArray(), function () {
      myself.initialConfig[this.name] = this.value;
    });
    
    this.styleTracks();
    this.showTracks();
    
    $('input.submit', this.el).hide();
    
    $('.popup_menu dt', '#' + this.id).live('click', function () {
      var menu = $(this).parent();
      var dt = menu.parent();
      var select = $('select', dt);
      var option = $('option[value=' + this.className + ']', select).attr('selected', 'selected');
      
      $('>img', dt).attr({ 
        src: '/i/render/' + this.className + '.gif', 
        title: option.text() 
      });
      
      menu.remove();
      
      menu = null;
      dt = null;
      select = null;
      option = null;
    });
    
    $('.configuration_search_text', this.el).keyup(function () {
      if (this.value.length < 3) {
        myself.lastQuery = this.value;
      }
      
      if (this.value != myself.lastQuery) {
        if (myself.searchTimer) {
          clearTimeout(myself.searchTimer);
        }
        
        myself.query = this.value;
        
        myself.searchTimer = setTimeout(function () { myself.search(); }, 250);
      }
    });
    
    if (Ensembl.ajax != 'enabled') {
      $('a', this.elLk.links).click(function () {
        var link = $(this).parent();
        
        if (!link.hasClass('active')) {
          myself.elLk.links.removeClass('active');
          link.addClass('active');
          myself.getContent();
        }
        
        link = null;
        
        return false;
      });
    }
  },
  
  getContent: function () {
    this.showTracks();
  },
  
  updateConfiguration: function (delayReload) {
    var myself = this;
    
    var d = false;
    var diff = { config: this.initialConfig.config };
    var checked = $.extend({}, this.initialConfig);
    
    $.each(this.elLk.form.serializeArray(), function () {
      if (this.value != myself.initialConfig[this.name]) {
        diff[this.name] = this.value;
        d = true;
      }
      
      delete checked[this.name];
    });
    
    // Add unchecked checkboxes to the diff
    for (var i in checked) {
      diff[i] = 'off';
      d = true;
    }
    
    if (d === true) {
      $.extend(this.initialConfig, diff);
      diff.submit = 1;
      
      this.updatePage(diff, delayReload);
      
      return true;
    }
  },
  
  updatePage: function (diff, delayReload) {
    var myself = this;
    
    if (Ensembl.ajax == 'enabled') {
      $.ajax({
        url: myself.elLk.form.attr('action'),
        type: myself.elLk.form.attr('method'),
        data: diff,
        dataType: 'html',
        success: function (html) {
          if (html == 'SUCCESS') {            
            // Reload the page
            // TODO: could reload only one section - would need panel id to be the same as diff.config, which it currently isn't
            Ensembl.EventManager.trigger(delayReload === true ? 'queuePageReload' : 'reloadPage');
          } else {
            // TODO: show message on main page
          }
        },
        error: function (e) {
         // TODO: show message on main page
        }
      });
    } else {
      var queryString = [];
      var url = this.elLk.form.attr('action') + '?';
      
      for (var i in diff) {
        queryString.push(i + '=' + diff[i]);
      }
      
      window.open(url + queryString.join(';'), window.name.replace(/^cp_/, '')); // URL to update configuration
      window.close();
    }
  },
  
  // TODO: currently only doing this on intial load - might be nicer to style every time we get results
  styleTracks: function () {
    var myself = this;
    
    var col = { 1: 'col1', '-1': 'col2', f: 1 };
    
    $('dl.config_menu', this.elLk.form).each(function () {
      $('dt', this).each(function () {
        $(this).addClass(col[col.f*=-1]).next('dd').addClass(col[col.f]);
      });
      
      col.f = 1;
    });
    
    $('dl.config_menu', this.elLk.form).each(function () {      
      $('dt', this).each(function () {
        var select = $('select', this);
        
        $('<img />').attr({
          src: '/i/render/' + select.val() + '.gif',
          title: select.attr('options')[select.attr('selectedIndex')].text
        }).click(function () {
          myself.makeMenu(this);
        }).insertAfter(select);
        
        select.hide();
        
        if ($(this).next().is('dd')) {
          $('<span class="menu_help">Show info</span>').click(function () {
            $(this).html(this.innerHTML == 'Show info' ? 'Hide info' : 'Show info').parent().next().toggle();
          }).appendTo(this);
        }
        
        select = null;
      });
      
      $('dd', this).hide();
    });
  },
  
  // TODO: swap link/menu ids for same class names. 
  showTracks: function () {
    var active = this.elLk.links.filter('.active').attr('id').replace(/link/, 'menu');
    
    $('div:not(#' + active + ')', this.elLk.form).hide();
    
    if (active == 'active_tracks') {
      $('dl.config_menu select', this.elLk.form).each(function () {
        if (this.value == 'off') {
          $(this).parent().hide().next().hide(); // Hide the dt and the dd corresponding to it
        } else {
          $(this).parents('dt, div.config').show();
        }
      });
    } else {
      $('#' + active, this.elLk.form).show().find('dl.config_menu dt').show();
    }
    
    this.lastQuery = false;
    this.elLk.search.val('');
  },
  
  // Filtering from the search box
  search: function () {
    var myself = this;
    
    this.elLk.links.removeClass('active');
    
    $('dl.config_menu', this.elLk.form).each(function () {
      var menu = $(this);
      var div = menu.parent();
      var show = false;
      
      $('dt', menu).each(function () {
        var dt = $(this);
        
        if ($('span', dt).html().match(myself.query, 'i') || dt.next('dd').text().match(myself.query, 'i')) {
          dt.show();
          show = true;
        } else {
          dt.hide().next('dd').hide();
        }
        
        dt = null;
      });
      
      if (show === true) {
        div.show();
      } else {
        div.hide();
      }
      
      menu = null;
      div = null;
    });
    
    this.lastQuery = this.query;
  },

  makeMenu: function (img) {
    var off = $(img).prev('.popup_menu').length;
    
    $('.popup_menu', this.el).remove();
    
    if (off) {
      return;
    }
    
    var menu = $('<dl class="popup_menu"></dl>').css('top', ($(img).position().top + this.el.scrollTop) + 'px');   
    
    $('option', $(img).prev()).each(function () {
      menu.append('<dt class="' + this.value + '"><img src="/i/render/' + this.value + '.gif" title="' + this.text + '" />' + this.text + '</dt>');
    });
    
    menu.insertBefore(img);
    
    menu = null;
  }
});
