/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2022] EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/** FIXME:
  hover labels for tracks don't link correctly to subtracks in popups
  only column nodes appear in track order - need all sortable nodes somehow
  
  TODO: 
  filter subtracks
  filter classes (<select>) for datahubs?
  
  (look at hiding rows outside the viewport to increase interaction speed in ie)
  (look at appending popup to cell, rather than wrapper)
  (remove column and row hovers from initial DOM (build template, attach/detach))
**/

Ensembl.Panel.ConfigMatrix = Ensembl.Panel.Configurator.extend({
  constructor: function (id, params) {
    this.base(id, params);
    
    Ensembl.EventManager.remove(id); // Get rid of all the Configurator events which we don't care about
    Ensembl.EventManager.register('mouseUp',              this, this.dragStop);
    Ensembl.EventManager.register('updateConfiguration',  this, this.updateConfiguration);
    Ensembl.EventManager.register('changeColumnRenderer', this, this.changeColumnRenderer);
    Ensembl.EventManager.register('modalPanelResize',     this, this.setScrollerSize);
  },
  
  init: function () {
    var panel = this;
    var j;
    
    Ensembl.Panel.prototype.init.call(this); // skip the Configurator init - does a load of stuff that isn't needed here
    
    this.startCell   = [];
    this.dragCell    = [];
    this.imageConfig = {};
    
    this.elLk.links         = this.params.links.find('> .count > .on');
    this.elLk.wrapper       = this.el.children('.config_matrix_wrapper');
    this.elLk.scroller      = this.el.children('.config_matrix_scroller').add(this.elLk.wrapper).on('scroll', function () { panel.elLk.scroller.not(this).scrollLeft(this.scrollLeft); });
    this.elLk.filterWrapper = this.el.children('.filter_wrapper');
    this.elLk.tableWrapper  = this.elLk.wrapper.children('.table_wrapper');
    this.elLk.noResults     = this.elLk.wrapper.children('.no_results');
    this.elLk.table         = this.elLk.tableWrapper.children('table.config_matrix');
    this.elLk.headers       = this.elLk.table.children('thead').children('tr:first').children('th');
    this.elLk.axisLabels    = this.elLk.headers.filter('.axes').find('i');
    this.elLk.configMenus   = this.elLk.table.children('thead').children('tr.config_menu').children('th');
    this.elLk.rows          = this.elLk.table.children('tbody').children('tr');
    this.elLk.columnHeaders = this.elLk.headers.add(this.elLk.configMenus).not('.first');
    this.elLk.cols          = [].slice.call($.map(this.elLk.table[0].rows[0].cells, function (c, i) { if (i) { return [[]]; } }));
    this.elLk.popup         = $();
    this.elLk.subtracks     = $();
    this.elLk.hiddenCells   = $();
    // new config sets stuff
    this.elLk.configForm        = this.el.closest('.panel').find('._config_settings');
    this.elLk.configDropdown    = this.elLk.configForm.find('._config_dropdown');
    this.elLk.configSelector    = this.elLk.configDropdown.find('select');

    this.elLk.tableWrapper.data('maxWidth', this.elLk.tableWrapper[0].style.width).width('auto');
    
    var headerLabels = this.elLk.columnHeaders.children('p');
    var height       = Math.max.apply(Math, headerLabels.map(function () { return $(this).width(); }).toArray());
    var width        = headerLabels.addClass('rotate').first().width();
    var axesHeight   = this.elLk.headers.filter('.axes').height();
    
    if (Ensembl.browser.ie) {
      headerLabels.css({ width: height, bottom: height - width });
      
      if (height > axesHeight) {
        this.elLk.tableWrapper.css('marginTop', height - axesHeight);
      }
    } else {
      var top = (height - width) / 2;
      headerLabels.css({ lineHeight: height + 'px', top: top });
      
      if (height > axesHeight) {
        this.elLk.tableWrapper.css('marginTop', -top / 2);
      }
    }
    
    headerLabels = null;
    
    this.elLk.axisLabels.each(function () {
      var el    = $(this);
      var clone = el.clone().addClass('clone').insertAfter(this);
      
      // labels are truncated
      if (clone.width() > el.width()) {
        el.data('fullLabel', $('<em class="floating_popup">' + this.innerHTML + '</em>').css($(this).position()).appendTo(el)).on({
          mouseenter: function () { $(this).data('fullLabel').show(); },
          mouseleave: function () { $(this).data('fullLabel').hide(); }
        });
      }
      
      clone.remove();
      
      el = clone = null;
    });
    
    for (var i = 0; i < this.elLk.table[0].rows.length; i++) {
      j = this.elLk.cols.length;
      
      while (j--) {
        this.elLk.cols[j].push(this.elLk.table[0].rows[i].cells[j + 1]);
      }
    }
    
    this.elLk.options = this.elLk.rows.children('.opt').each(function () {
      var el = $(this);
      
      this.configCode  = panel.id + '_' + this.title.replace(':', '_');
      this.searchTerms = $.trim(this.parentNode.className + ' ' + panel.elLk.headers.eq(el.index()).children('p').html() + ' ' + this.title).toLowerCase();
      panel.imageConfig[this.configCode] = { renderer: el.hasClass('on') ? 'on' : 'off' };
      
      el = null;
    });
    
    this.elLk.tracks = this.elLk.configMenus.not('.select_all').each(function () {
      var track = panel.tracks[this.id];
      
      panel.imageConfig[this.id] = { renderer: track.renderer };
      $.extend(track, { el: $(this), linkedEls: panel.params.parentTracks[this.id].el });
      $(this).data('track', track);
      
      if (track.renderer !== panel.params.parentTracks[this.id].renderer) {
        panel.changeColumnRenderer($(this), panel.params.parentTracks[this.id].renderer);
      }
    }).removeAttr('id');
    
    this.setEventHandlers();
    this.tutorial();
    this.setScrollerSize();
    
    // Fix z-index for popups in IE6 and 7
    if (Ensembl.browser.ie67) {
      this.elLk.headers.css('zIndex',     function (i) { return 200 - i; });
      this.elLk.configMenus.css('zIndex', function (i) { return 100 - i; });
    }
  },
  
  setEventHandlers: function () {
    var panel = this;
    
    this.el.children('.header_wrapper').children('.help').on('click', function () {
      $(this).toggleClass('open').attr('title', function (i, title) {
        return title === 'Hide information' ? 'Click for more information' : 'Hide information';
      }).siblings('.desc').width($(this).parent().width() - 25).toggle();
      
      return false;
    });
    
    this.elLk.filterWrapper.children('select.filter').on('change', function () {
      panel.elLk.rows.removeClass('hidden');
      
      if (this.value) {
        panel.elLk.rows.not('.' + this.value).addClass('hidden');
      }
      
      panel.afterFilter();
    });
    
    this.elLk.filterWrapper.children('input.filter').on({
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
          this.value = this.defaultValue;
          this.style.color = '#999';
        }
      }
    });
    
    if (!Ensembl.browser.ie) { // IE 8 and below are too slow
      this.elLk.table.on('mousedown', function (e) {
        // only for left clicks, create a highlight overlay to show which cells are being dragged over
        if ((!e.which || e.which === 1) && /^(TD|P|SPAN)$/.test(e.target.nodeName)) {
          panel.dragStart(e);
        }
        
        return false;
      });
    }
    
    this.elLk.table.children('thead').children('tr.config_menu')
    .on('click', 'th',             $.proxy(this.showConfigMenu,  this))
    .on('click', '.popup_menu li', $.proxy(this.setColumnConfig, this));
    
    // Display a select all popup for columns
    this.elLk.headers.not('.axes').on({
      mouseenter: function () {
        if (panel.mousemove) {
          return;
        }
        
        panel.selectAllCol($(this).children('div').show());
      },
      mouseleave: function () {
        $(this).children('div').hide();
      }
    }).children('.select_all_column').find('input').on('click', function (e) {
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
      
      // e.stopPropagation();
    });
    
    // Display a select all popup for rows
    this.elLk.rows.children('th').on({
      mouseenter: function () {
        if (panel.mousemove) {
          return;
        }
      
        var popup = $(this).find('.select_all_row').show();
        
        if (!popup.data('selectAll')) {
          popup.children('input').prop('checked', panel.allOnRow(this));
          popup.data('selectAll', true);
        }
        
        popup = null;
      },
      mouseleave: function () {
        $(this).find('.select_all_row').hide();
      }
    }).find('.select_all_row').on('click', function (e) {
      var input   = $('input', this);
      var th      = $(this).parents('th');
      var checked = panel.allOnRow(th[0]);
      
      panel.resetSelectAll(th.siblings('.opt')[checked ? 'removeClass' : 'addClass']('on'));
      
      input.prop('checked', !checked);
      input = th = null;
      
      // e.stopPropagation();
    });
    
    this.elLk.configMenus.filter('.select_all').children('.popup_menu').children('li:not(.header)').on('click', function () {
      panel.changeColumnRenderer($(this).parent().hide().parent().siblings().filter(function () { return this.style.display !== 'none'; }), this.className);
      return false;
    });
    
    this.elLk.table.children('tbody').on('click', '.opt', function () {
      var el         = $(this).toggleClass('on');
      var cellTracks = panel.params.cellTracks ? $.trim(panel.params.cellTracks[this.title]) : false;
      var popup, colTrack;

      if (cellTracks && el.hasClass('on')) {
        panel.removePopups();
        
        popup = el.data('subtracks');
        
        if (!popup) {
          popup = $(cellTracks);
          
          $('.popup_menu li',                           popup).on('click', $.proxy(panel.setTrackConfig, panel));
          $('> ul.config_menu > li.track, .select_all', popup).on('click', $.proxy(panel.showConfigMenu, panel)).not('.select_all').each(function () {
            $(this).data({ track: $.extend(panel.tracks[this.id], { el: $(this) }), popup: $(this).children('.popup_menu') });
          }).removeAttr('id');
          
          popup.children('.close').on('click', function () {
            panel.removePopups($(this).parent());
            return false;
          });
          
          colTrack = panel.elLk.configMenus.eq(el.index()).data('track');
          
          panel.setDefaultRenderer(popup.data({ cell: el, colTrack: colTrack }), colTrack.renderer);
          el.data('subtracks', popup);
          
          panel.elLk.subtracks.push(popup[0]);
          panel.elLk.tracks.push.apply(panel.elLk.tracks, popup.find('.track').each(function () {
            var track = $(this).data('track');
            panel.imageConfig[track.id] = { renderer: track.renderer };
          }).toArray());
        }
        
        popup.appendTo(panel.elLk.wrapper).position({ of: this, within: panel.elLk.wrapper, my: 'left top', collision: 'flipfit' });
      } 
      
      if (cellTracks) {
        panel.updateLinkCount();
      } else {
        panel.resetSelectAll(el);
      }
      
      el = popup = null;
      
      return false;
    });
  },
  
  showConfigMenu: function (e) {
    var el    = $(e.currentTarget);
    var popup = el.data('popup');
    
    this.base(e);
    
    if (popup) {
      popup.position({
        of:        el,
        within:    this.elLk.wrapper,
        my:        el.hasClass('select_all') ? 'left bottom+2' : 'left+8 top',
        at:        el.hasClass('select_all') ? 'left top'      : 'left center',
        collision: 'flipfit'
      });
    }
    
    el = popup = null;
    
    return false;
  },
  
  setColumnConfig: function (e) {
    var target = $(e.target);
    
    if (!target.is('.header') && !target.filter('.close').parents('.popup_menu').hide().length) {
      this.changeColumnRenderer(target.parent().hide().parent(), target[0].className);
    }
    
    target = null;
    
    return false;
  },
  
  setTrackConfig: function (e) {
    var target = $(e.target);
    
    if (target.is('.header') || target.filter('.close').parents('.popup_menu').hide().length) {
      target = null;
      return false;
    }

    var popup     = target.parents('.subtracks');
    var cell      = popup.data('cell');
    var colTrack  = popup.data('colTrack');
    var isDefault = e.currentTarget.className === 'default';
    
    if (isDefault) {
      e.target = e.currentTarget; // target is the div inside the li, rather than the li itself - base function needs the target to be the li
    }
    
    this.base(e, false);
    
    if (isDefault) {
      // change all tracks in the popup for select all = default
      target.parents('.track').add(target.parents('.select_all').siblings('ul.config_menu').children('.track'))[colTrack.renderer === 'off' ? 'removeClass' : 'addClass']('on')
        .children('div').removeClass().addClass(colTrack.renderer);
    }
    
    this.params.defaultRenderers[cell[0].title] = $('> ul.config_menu > li.default', popup).length;
    cell.find('span.on').html(popup.find('li.track.on').length);
    
    this.updateLinkCount();
    
    target = popup = cell = null;
    
    return false;
  },
  
  changeColumnRenderer: function (tracks, renderer, fromMainPanel) {
    var panel = this;
    
    if (fromMainPanel) {
      tracks = $($.map(tracks, function (id) { return panel.tracks[id] ? panel.tracks[id].el[0] : undefined; }));
    }
    
    if (tracks.length) {
      this.changeTrackRenderer(tracks, renderer, true);
    }

    tracks = null;
    
    return true;
  },
  
  changeTrackRenderer: function (tracks, renderer, isColumn) {
    var panel = this;
    var on    = tracks.map(function () { return $(this).hasClass('on'); }).toArray();
    var track;
    
    this.base(tracks, renderer, false, true);
    
    if (isColumn) {
      if (this.params.defaultRenderers) {
        tracks.each(function (i) {
          track = $(this);
          if (track.hasClass('on') !== on[i]) {
            panel.elLk.options.filter('.' + track.data('track').colClass).find('.on').html(function (j, html) {
              return parseInt(html, 10);
            });
          }
        });
      }
      
      this.setDefaultRenderer(this.elLk.subtracks.filter(function () { return tracks.filter($(this).data('colTrack').el[0]).length; }), tracks.data('track').renderer);
      this.updateLinkCount();
    }
    
    tracks = track = null;
  },
  
  setDefaultRenderer: function (tracks, renderer) {
    tracks.find('li.default').filter('.track')[renderer === 'off' ? 'removeClass' : 'addClass']('on').end().children('div').removeClass().addClass(renderer);
  },
  
  // FIXME: often called multiple times for one operation
  updateLinkCount: function () {
    var on   = 0;
    var link = this.elLk.links.last();
    var old  = parseInt(link.html(), 10);
    
    if (this.params.cellTracks) {
      this.elLk.options.filter('.on').find('.on').each(function () { on += parseInt(this.innerHTML, 10); });
    } else {
      on = this.elLk.configMenus.filter('.on').length;
    }
    
    link.html(on);
    
    this.elLk.links.first().html(function (i, html) { return parseInt(html, 10) + (on - old); });
    
    link = null;
  },
  
  removePopups: function () {
    (arguments[0] || this.elLk.subtracks.filter(function () { return this.parentNode; })).detach().each(function () {
      var popup = $(this);
      
      if (!popup.find('li.track.on').length) {
        popup.data('cell').removeClass('on');
      }
      
      popup = null;
    });
  },
  
  tutorial: function () {
    var panel = this;
    
    if (Ensembl.browser.ie67) {
      return;
    }
    
    this.showTutorial = Ensembl.cookie.get('config_matrix_tutorial') !== 'off';
    
    this.elLk.tutorial = $('.tutorial', this.el);
    
    if (this.showTutorial) {
      this.elLk.tutorial.css('display', 'block');
    }
    
    this.elLk.tutorialToggle = this.el.find('.toggle_tutorial, span.close').on('click', function () {
      panel.showTutorial = !panel.showTutorial;
      panel.elLk.tutorial.css('display', panel.showTutorial ? 'block' : 'none');
      panel.el.find('.toggle_tutorial')[panel.showTutorial ? 'addClass' : 'removeClass']('on');
      Ensembl.cookie.set('config_matrix_tutorial', panel.showTutorial ? 'on' : 'off');
      
      return false;
    })[panel.showTutorial ? 'addClass' : 'removeClass']('on');
  },
  
  setScrollerSize: function () {
    if (!this.el.parent().data('active')) {
      return;
    }
    
    // IE is to slow to calculate widths, so use estimates
    var wide = Ensembl.browser.ie ? parseInt(this.elLk.tableWrapper.data('maxWidth'), 10) > this.params.width : this.elLk.table.width() > this.el.width(); 
    
    this.elLk.wrapper[wide ? 'addClass' : 'removeClass']('wide');
    this.elLk.tableWrapper.width(wide ? this.elLk.tableWrapper.data('maxWidth') : 'auto');
    
    if (!Ensembl.browser.ie) {
      this.elLk.scroller.eq(0).children().width(wide ? this.elLk.wrapper[0].scrollWidth : 'auto');
    }
  },
  
  allOnRow: function (el) {
    var tds  = $(el).siblings('.opt');
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
    var i, className, col, data, off, on;
    
    cells.each(function () {
      reset.row[$(this).parent().index()] = 1;
      reset.col[$(this).index()] = 1;
    });
    
    for (i in reset.row) {
      $('th .select_all_row', this.elLk.rows[i]).data('selectAll', false);
    }
    
    for (i in reset.col) {
      className = $('.select_all_column', this.elLk.headers[i]).data('selectAll', false).parent().attr('class');
      col       = this.elLk.configMenus.filter('.' + className);
      data      = col.data();
      on        = !!this.elLk.rows.children('.on.' + className).length;
      off       = data.track.renderer === 'off';
      
      if (off === on) {
        data.popup = data.popup || $(data.track.popup).prependTo(col);
        data.popup.children().removeClass('current').filter('li.off' + (on ? ' +' : '')).trigger('click'); // Doesn't trigger renderer change correctly if "current" class is not removed first
      }
    }
    
    if (cells.find('.on').length) {
      this.updateLinkCount();
    }
    
    cells = col = null;
  },
  
  // Called by triggerSpecific from the parent Configurator panel.
  // Does not cause an AJAX request, just returns the diff data.
  updateConfiguration: function (subPanel, force) {

    if (subPanel !== this.id) {
      return;
    }

    var panel  = this;
    var config = {};
    var diff   = false;
    var on;
    
    this.elLk.options.each(function () {
      on = $(this).hasClass('on') ? 'on' : 'off';
      if (panel.imageConfig[this.configCode].renderer !== on || force) {
        config[this.configCode] = { renderer: on };
        diff = true;
      }
    });
    
    this.elLk.tracks.each(function () {
      var track = $(this).data('track');
      if (panel.imageConfig[track.id].renderer !== track.renderer || force) {
        config[track.id] = { renderer: track.renderer };
        diff = true;
      }
    });

    if (diff) {
      $.extend(true, this.imageConfig, config);
      return { imageConfig: config };
    }
  },

  dragStart: function (e) {
    var target = e.target.nodeName === 'P' ? $(e.target.parentNode) : e.target.nodeName === 'SPAN' ? $(e.target.parentNode.parentNode) : $(e.target);    
    
    if (target[0].nodeName !== 'TD') {
      target = null;
      return;
    }
    
    this.mousemove = { x: e.pageX, y: e.pageY };
    this.startCell = [ target.index(), target.parent().index() + 2 ]; // cell and row coordinates
    
    this.elLk.table.on('mousemove', $.proxy(this.drag, this));
    this.removePopups();
    
    target = null;
  },
  
  dragStop: function () {
    if (!this.mousemove) {
      return;
    }
    
    this.elLk.table.off('mousemove');
    
    var highlighted = $('.highlight', this.elLk.table).removeClass('highlight');
    
    // If only one cell is highlighted, it'll be picked up by the click
    if (highlighted.length > 1) {
      var options = highlighted.filter('.opt');
      
      if (options.length === 1) {
        options.trigger('click');
      } else {
        this.resetSelectAll(options.toggleClass('on'));
      }
      
      options = null;
    }
    
    this.mousemove = false;
    this.dragCell  = [];
    
    highlighted = null;
  },
  
  drag: function (e) {
    if (Math.abs(e.pageX - this.mousemove.x) < 3 && Math.abs(e.pageY - this.mousemove.y) < 3) {
      return; // set a drag threshold
    }
    
    var target = e.target.nodeName === 'P' ? $(e.target.parentNode) : e.target.nodeName === 'SPAN' ? $(e.target.parentNode.parentNode) : $(e.target);    
    
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
    $(cells).not('.highlight').addClass('highlight').not(':has(p)').append('<p></p>');
    
    this.dragCell = cell;
    
    target = cells = null;
  },
  
  filter: function (value) {
    var cells      = [];
    var rows       = [];
    var rowMatches = {};
    var colMatches = {};
    var values, match, options, els, i, j;
    
    if (value) {
      options = this.elLk.options.filter(function () { return this.style.display !== 'none'; });
      value   = value.toLowerCase();
      match   = value.match(/(?:"[^"]+"|'[^']+')/g);
      values  = match ? $.map(match, function (match) { return match.replace(/^["']/, '').replace(/["']$/, ''); }) : [ value ];
      
      for (i in values) {
        value = $.trim(values[i]); // remove extra whitespace
        
        if (value === '') {
          continue;
        }
        
        value = value.split(' ');
        
        options.each(function () {
          match = true;
          
          for (j in value) {
            if (this.searchTerms.indexOf(value[j]) === -1) {
              match = false;
              break;
            }
          }
          
          if (match) {
            cells.push(this);
            rowMatches[$(this.parentNode).index()] = colMatches[$(this).index() - 1] = true;
          }
        });
      }
      
      if (cells.length) {
        els = { show: $(), hide: $() };
        
        for (i in rowMatches) {
          rows.push(this.elLk.rows[i]);
        }
        
        this.elLk.rows.not(rows).css('display', 'none');
        this.elLk.options.filter('.filter').removeClass('filter');
        $(cells).addClass('filter');
        
        $(rows).show().each(function () {
          for (i = 1; i < this.cells.length; i++) {
            els[colMatches[i - 1] ? 'show': 'hide'].push(this.cells[i]);
          }
        });
        
        this.elLk.columnHeaders.each(function () {
          els[colMatches[$(this).index() - 1] ? 'show': 'hide'].push(this);
        });
        
        els.show.css('display', '');
        els.hide.css('display', 'none');
        
        this.elLk.hiddenCells = this.elLk.hiddenCells.add(els.hide.not(this.elLk.hiddenCells));
      } else {
        this.elLk.rows.css('display', 'none');
      }
    } else {
      this.elLk.options.filter('.filter').removeClass('filter');
      this.elLk.rows.filter(function () { return this.style.display === 'none'; }).add(this.elLk.hiddenCells).css('display', '');
      this.elLk.hiddenCells = $();
    }
    
    this.afterFilter();
  },

  afterFilter: function () {
    var shown = this.elLk.rows.filter(function () { return this.style.display !== 'none' && this.className.indexOf('hidden') === -1; }).length;
    
    if (!shown) {
      this.elLk.popup.hide();
    }
    
    if (this.showTutorial) {
      this.elLk.tutorialToggle.trigger('click');
    }
    
    this.elLk.table[shown < 4 ? 'addClass' : 'removeClass']('short');
    this.elLk.noResults[shown ? 'hide' : 'show']();
    this.setScrollerSize();
  }
});
