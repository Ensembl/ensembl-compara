// $Revision$

Ensembl.Panel.FuncgenMatrix = Ensembl.Panel.ModalContent.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    Ensembl.EventManager.register('mouseUp',             this, this.dragStop);
    Ensembl.EventManager.register('updateConfiguration', this, this.updateConfiguration);
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    this.startCell   = [];
    this.dragCell    = [];
    this.imageConfig = {};
    this.viewConfig  = {};
    
    this.elLk.table = $('table.funcgen_matrix', this.el);
    
    var colClasses = $.map(this.elLk.table[0].rows[0].cells, function (el) { return el.className; });
    var linkData   = $.map(this.params.links, function (link) { return 'a.' + link; }).join(', ');
    
    this.elLk.noResults  = $('.no_results',           this.el);
    this.elLk.headers    = $('thead tr:first th',     this.elLk.table);
    this.elLk.renderers  = $('thead tr.renderers th', this.elLk.table);
    this.elLk.rows       = $('tbody tr',              this.elLk.table);
    this.elLk.trackNames = $('.track_name',           this.elLk.renderers).each(function () { panel.imageConfig[this.name] = { renderer: this.value }; });
    this.elLk.menus      = $('.popup_menu',           this.elLk.renderers);
    this.elLk.options    = $('.option',               this.elLk.rows).each(function () {      
      this.configCode  = 'opt_cft_' + this.title; // configCode is used to set the correct values for the ViewConfig
      this.searchTerms = $.trim(this.parentNode.className + ' ' + colClasses[$(this).index()]).toLowerCase(); // Do this here so we don't have to look up the header row for every cell
      panel.viewConfig[this.configCode] = $(this).hasClass('on') ? 'on' : 'off';
    }).on('click', function () {
      panel.resetSelectAll($(this).toggleClass('on'));
    });
    
    $('.help', this.el).on('click', function () {
      $(this).toggleClass('open').attr('title', function (i, title) {
        return title === 'Hide information' ? 'Click for more information' : 'Hide information';
      }).siblings('.desc').width($(this).parent().width() - 25).toggle();
    });
    
    $('select.filter', this.el).on('change', function () {
      panel.elLk.rows.removeClass('hidden');
      
      if (this.value) {
        panel.elLk.rows.not('.' + this.value).addClass('hidden');
      }
      
      panel.elLk.noResults[panel.elLk.rows.filter(function () { return this.style.display !== 'none' && this.className.indexOf('hidden') === -1; }).length ? 'hide' : 'show']();
    });
    
    $('input.filter', this.el).on({
      keyup: function () {
        var value = this.value;
        
        if (value && value.length < 2) {
          this.lastQuery = value;
        }
        
        if (value !== this.lastQuery) {
          if (this.searchTimer) {
            clearTimeout(this.searchTimer);
          }
          
          this.searchTimer = setTimeout(function () {
            panel.filter(value);
          }, 250);
        }
      },
      focus: function () {
        this.value = '';
        this.style.color = '#000';
      },
      blur: function () {
        if (!this.value) {
          panel.filter();
          this.value = 'Enter cell or evidence types';
          this.style.color = '#999';
        }
      }
    });
    
    if (!$('body').hasClass('ie')) { // IE 8 and below are too slow
      this.elLk.table.on('mousedown', function (e) {
        // only for left clicks, create a highlight overlay to show which cells are being dragged over
        if ((!e.which || e.which === 1) && (e.target.nodeName === 'TD' || e.target.nodeName === 'P')) {
          panel.dragStart(e);
        }
        
        return false;
      });
    }
    
    $('.menu_option', this.elLk.renderers).on('click', function () { 
      panel.elLk.menus.not(this).hide(); 
    });
    
    // Display a select all popup for columns
    this.elLk.headers.not('.disabled').hover(function () {
      if (panel.mousemove) {
        return;
      }
      
      panel.selectAllCol($(this).children('div').show());
    }, function () {
      $(this).children('div').hide();
    }).find('.select_all_column input').on('click', function () {
      var cls   = this.className;
      var cells = panel.elLk.rows.children('.' + this.name);
      
      switch (cls) {
        case ''     : break;
        case 'none' : cells.removeClass('on'); break;
        case 'all'  : cells.addClass('on');    break;
        default     : cells.filter('.' + cls).addClass('on').end().not('.' + cls).removeClass('on');
      }
      
      panel.resetSelectAll(cells);
      
      cells = null;
    });
    
    // Display a select all popup for rows
    $('th', this.elLk.rows).hover(function () {
      if (panel.mousemove) {
        return;
      }
    
      var popup = $(this).children().show();
      
      if (!popup.data('selectAll')) {
        popup.children('input').prop('checked', panel.allOnRow(this));
        popup.data('selectAll', true);
      }
      
      popup = null;
    }, function () {
      $(this).children().hide();
    }).children('.select_all_row').on('click', function () {
      var input   = $('input', this);
      var checked = panel.allOnRow(this.parentNode);
      
      panel.resetSelectAll($(this).parent().siblings('.option')[checked ? 'removeClass' : 'addClass']('on'));
      
      input.prop('checked', !checked);
      input = null;
    });
    
    this.elLk.renderers.filter('.select_all').find('.popup_menu li').on('click', function () {
      $(this).parents('.popup_menu').hide().parent().siblings().find('.popup_menu li.' + this.className).trigger('click');
      return false;
    });
    
    this.elLk.renderers.not('.select_all').data('links', linkData);
    
    // Fix z-index for popups in IE6 and 7
    if ($('body').hasClass('ie67')) {
      this.elLk.headers.css('zIndex',   function (i) { return 200 - i; });
      this.elLk.renderers.css('zIndex', function (i) { return 100 - i; });
    }
    
    this.tutorial();
  },
  
  tutorial: function () {
    var panel = this;
    
    this.showTutorial = Ensembl.cookie.get('funcgen_matrix_tutorial') !== 'off';
    
    var col = panel.elLk.headers.length > 4 ? panel.elLk.headers.length < 12 ? -1 : 11 : 3;
    
    this.elLk.tutorial = $('div.tutorial', this.el)[this.showTutorial ? 'show' : 'hide']().each(function () {
      var css, pos, tmp;
      
      switch (this.className.replace(/tutorial /, '')) {
        case 'track':     css = { top: panel.elLk.renderers.eq(1).position().top - 73 }; break;
        case 'all_track': pos = panel.elLk.renderers.first().position(); css = { top: pos.top + 25, left: pos.left + 50 }; break;
        case 'col':       css = { top: panel.elLk.rows.eq(5).find('th').position().top + 15 }; break;
        case 'row':       tmp = panel.elLk.headers.eq(col); pos = tmp.position(); css = { top: pos.top - 50, left: pos.left + tmp.width() }; break;
        case 'drag':      tmp = panel.elLk.rows.eq(4); css = { top: tmp.position().top, left: tmp.children().eq(col).position().left + 10 }; break;
        default:          return;
      }
      
      $(this).css(css);
      
      tmp = null;
    });
    
    $('.toggle_tutorial', this.el).on('click', function () {
      panel.showTutorial = !panel.showTutorial;
      panel.elLk.tutorial.toggle();
      $(this)[panel.showTutorial ? 'addClass' : 'removeClass']('on');
      Ensembl.cookie.set('funcgen_matrix_tutorial', panel.showTutorial ? 'on' : 'off');
    })[panel.showTutorial ? 'addClass' : 'removeClass']('on');
  },
  
  allOnRow: function (el) {
    var tds  = $(el).siblings(':not(.disabled)');
    var rtn  = tds.length === tds.filter('.on').length;
    tds = el = null;
    return rtn;
  },
  
  selectAllCol: function (el) {
    if (!el.length || el.data('selectAll')) {
      return;
    }
    
    var radio = el.find('input');
    var tds   = this.elLk.rows.children('.' + radio[0].name);
    var on    = tds.filter('.on');
    var checked, i, cls, filtered;
    
    if (tds.length === tds.filter('.default').length) {
      checked = '.default'; // Prioritize the Default option
    } else if (!on.length) {
      checked = '.none';
    } else if (tds.length === on.length) {
      checked = '.all';
    }
    
    if (checked) {
      radio.filter(checked).prop('checked', true);
    } else {
      checked = radio.filter(':checked');
      radio   = radio.not('.all, .none');
      i       = radio.length;
      
      while (i--) {
        cls      = radio[i].className;
        filtered = tds.filter('.' + cls);
        
        if (filtered.length === on.length && filtered.length === on.filter('.' + cls).length) {
          radio[i].checked = 'checked';
          break;
        }
      }
      
      if (i === -1) {
        checked.prop('checked', false); // Deselect all options if nothing matches
      }
      
      checked = null;
    }
    
    el.data('selectAll', true);
    
    el = radio = tds = null;
  },
  
  // Sets the selectAll state of relevant column and row headers to false,
  // so they will be recalculated the next time the th mouseover is triggered.
  resetSelectAll: function (cells) {
    var reset = { row: {}, col: {} };
    var i, className, renderer, off, on;
    
    cells.each(function () {
      reset.row[$(this).parent().index()] = 1;
      reset.col[$(this).index()] = 1;
    });  
    
    for (i in reset.row) {
      $('th .select_all_row', this.elLk.rows[i]).data('selectAll', false);
    }
    
    for (i in reset.col) {
      className = $('.select_all_column', this.elLk.headers[i]).data('selectAll', false).parent().attr('class');
      renderer  = this.elLk.renderers.filter('.' + className).find('.track_name');
      off       = renderer.val() === 'off';
      on        = !!this.elLk.rows.children('.' + className + '.on').length;
      
      if (off === on) {
        renderer.siblings('.popup_menu').children(':not(.header):eq(' + (on ? 1 : 0) + ')').trigger('click');
      }
    }
    
    cells = null;
  },
  
  // Called by triggerSpecific from the parent Configurator panel.
  // Does not cause an AJAX request, just returns the diff data.
  updateConfiguration: function (subPanel) {
    if (subPanel !== this.id) {
      return;
    }
    
    var panel  = this;
    var config = { viewConfig: {}, imageConfig: {} };
    var diff   = false;
    var on;
    
    this.elLk.options.each(function () {
      on = $(this).hasClass('on') ? 'on' : 'off';
      
      if (panel.viewConfig[this.configCode] !== on) {
        config.viewConfig[this.configCode] = on;
        diff = true;
      }
    });
    
    this.elLk.trackNames.each(function () {
      if (panel.imageConfig[this.name].renderer !== this.value) {
        config.imageConfig[this.name] = { renderer: this.value };
        diff = true;
      }
    });
    
    if (diff) {
      $.extend(true, this.viewConfig,  config.viewConfig);
      $.extend(true, this.imageConfig, config.imageConfig);
      return config;
    }
  },
    
  dragStart: function (e) {
    var panel  = this;
    var target = $(e.target);
    
    // Cache the mousemove event for easy unbinding
    this.mousemove = function (e2) {
      panel.drag(e2);
      return false;
    };
    
    this.startCell = [ target.index(), target.parent().index() + 2 ]; // cell and row coordinates
    this.elLk.table.on('mousemove', this.mousemove);
    
    target = null;
  },
  
  dragStop: function () {
    if (!this.mousemove) {
      return;
    }
    
    this.resetSelectAll($('.highlight', this.elLk.table).removeClass('highlight').not('.disabled').toggleClass('on'));
    this.elLk.table.off('mousemove', this.mousemove);
    this.mousemove = false;
  },
  
  drag: function (e) {
    var target = e.target.nodeName === 'P' ? $(e.target.parentNode) : $(e.target);    
    
    if (target[0].nodeName !== 'TD') {
      target = null;
      return;
    }
    
    var cell = [ target.index(), target.parent().index() + 2 ];
    
    if (cell[0] === this.dragCell[0] && cell[1] === this.dragCell[1]) {
      return; // Target is unchanged
    }
    
    var x     = [ cell[0], this.startCell[0] ].sort(function (a, b) { return a - b; });
    var y     = [ cell[1], this.startCell[1] ].sort(function (a, b) { return a - b; });
    var cells = [];
    var i, j;
    
    for (i = y[0]; i <= y[1]; i++) {
      if (this.elLk.table[0].rows[i].style.display !== 'none' && this.elLk.table[0].rows[i].className !== 'gap') {
        for (j = x[0]; j <= x[1]; j++) {
          cells.push(this.elLk.table[0].rows[i].cells[j]); // Get the cells in the rows and columns between the current target and the start cell
        }
      }
    }
    
    $('.highlight', this.elLk.table).not(cells).removeClass('highlight');
    $(cells).not('.highlight').addClass('highlight');
    
    this.dragCell = cell;
    
    target = cells = null;
  },
  
  filter: function (value) {
    var cells      = [];
    var rows       = [];
    var rowMatches = {};
    var i;
    
    if (value) {
      value = $.trim(value.toLowerCase()).split(' '); // remove extra whitespace
      
      this.elLk.options.each(function () {
        for (i in value) {
          if (this.searchTerms.indexOf(value[i]) !== -1) {
            cells.push(this);
            rowMatches[$(this.parentNode).index()] = true;
            break;
          }
        }
      });
      
      if (cells.length) {
        for (i in rowMatches) {
          rows.push(this.elLk.rows[i]);
        }
      
        this.elLk.rows.not(rows).hide();
        this.elLk.options.filter('.filter').removeClass('filter');
        $(rows).show();
        $(cells).addClass('filter');
      } else {
        this.elLk.rows.hide();
      }
    } else {
      this.elLk.rows.show();
      this.elLk.options.filter('.filter').removeClass('filter');
    }
    
    this.elLk.noResults[this.elLk.rows.filter(function () { return this.style.display !== 'none' && this.className.indexOf('hidden') === -1; }).length ? 'hide' : 'show']();
  }
});
