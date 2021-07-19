/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2021] EMBL-European Bioinformatics Institute
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

Ensembl.Panel.Masthead = Ensembl.Panel.extend({
  constructor: function (id) {
    this.longTabs        = false;
    this.moreShown       = false;
    this.recentLocations = {};
  
    this.base(id);
    
    Ensembl.EventManager.register('windowResize',   this, this.resize);
    Ensembl.EventManager.register('hashChange',     this, this.hashChange);
    Ensembl.EventManager.register('deleteBookmark', this, this.deleteBookmark);
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    var tabsHolder  = $('.tabs_holder', this.el);
    var tabs        = $('.tabs', tabsHolder);
    var spbarHolder = $('.spbar_holder', this.el);
    var tools       = $('.tools_holder', this.el);
    var logo        = $('.logo_holder', this.el);   
    
    this.elLk.allTabs    = $('li', tabs);
    this.elLk.shortTabs  = $('li.short_tab', tabs);
    this.elLk.longTabs   = $('li.long_tab', tabs);
    this.elLk.toolsUl    = $('.tools', tools);
    this.elLk.tools      = $('li', this.elLk.toolsUl);
    this.elLk.toolMore   = $('.more', tools);
    this.elLk.toolMoreUl = $('<ul class="more_tools" />').appendTo(this.elLk.toolMore);
    this.elLk.dropdowns  = $('div.dropdown', tabsHolder).on('click', function () {
      $(this).css('zIndex', ++Ensembl.PanelManager.zIndex);
    });
    this.el.find('._ht').helptip();
    
    // Cache the text on the recent location links, to stop hash changes in the URL from duplicating entries in the menu
    this.elLk.dropdowns.filter('.location').find('ul.recent li a').each(function () {
      panel.recentLocations[$(this).text()] = 1;
    });
    
    
    // Send an ajax request to clear the user's history for a tab/dropdown
    $('a.clear_history', this.elLk.dropdowns).on('click', function () {
      var li = $(this).parent();
      
      $.ajax({
        url: this.href,
        success: function () {
          var lis = li.parents('.dropdown').find('.recent li');
          
          li.remove();
          panel.deleteFromDropdown(lis);
          
          lis = li = null;
        }
      });
      
      return false;
    });
    
    if (window.location.hash) {
      this.hashChange(Ensembl.urlFromHash(window.location.href, true), true);
    }
    
    // Show the relevant dropdown when a toggle link is clicked
    $('.toggle', tabs).each(function () {
      $(this).data('cls', '.' + (this.rel || this.title)).removeAttr('title');
    }).on('click', function () {
      var cls      = $(this).data('cls');
      var dropdown = panel.elLk.dropdowns.filter(cls);
      
      panel.dropdownPosition(dropdown, $(this).parents('li'));
      dropdown.not(':visible').css('zIndex', ++Ensembl.PanelManager.zIndex).end().toggle(); 
      panel.elLk.allTabs.filter(cls).find('a.toggle').html(dropdown.is(':visible') ? '&#9650;' : '&#9660;'); // Change the toggle arrow from up to down or vice versa
      dropdown.data('type', cls); // Cache the selector to find the tab for use later
      
      dropdown = null;
      
      return false;
    });
   
    // New species bar 
    this.elLk.sppDropdown = $('div.dropdown', spbarHolder).on('click', function () {
      $(this).css('zIndex', ++Ensembl.PanelManager.zIndex);
    });
    this.elLk.sppToggle = $('a.toggle', spbarHolder).on('click', function () {
      var dropdown = panel.elLk.sppDropdown;
      panel.dropdownPosition(dropdown, $(this));
      dropdown.not(':visible').css('zIndex', ++Ensembl.PanelManager.zIndex).end().toggle(); 
      $(this).html(dropdown.is(':visible') ? '&#9650;' : '&#9660;'); // Change the toggle arrow from up to down or vice versa
      dropdown = null;
      return false;
    });
    
    this.elLk.toolMore.children('a').on('click', function () {
      $(this).toggleClass('open');
      panel.elLk.toolMoreUl.html(panel.elLk.toolsOverflow.clone()).toggle();
      panel.moreShown = true;
      return false;
    });
    
    this.toolsShown = this.elLk.tools.length;
    
    this.widths = {
      search: $('.search_holder', this.el).outerWidth(true),
      logo:   logo.outerWidth(true) + logo.offset().left,
      more:   this.elLk.toolMore.outerWidth(true)
    };
    
    this.setWidth('tools');
    
    this.elLk.longTabs.show();
    this.setWidth('longTabs');
    this.elLk.longTabs.hide();
    
    this.resize();
    
    tabsHolder = tabs = tools = logo = null;
  },
  
  // Set the left position of a dropdown as the left position of its related tab
  // Set the width of the dropdown to be the width of the tab if the tab is wider
  // Cache the position so this only has to be done once
  dropdownPosition: function (dropdown, tab, force) {
    var css = {};
    var tabWidth, dropdownWidth;
    
    if (force || !dropdown.data('positioning:' + this.longTabs)) {
      tabWidth      = tab.outerWidth();
      dropdownWidth = dropdown.outerWidth();
      
      css.left = tab.offset().left;
      
      if (!tab.hasClass('species')) {
        css.width = tabWidth > dropdownWidth ? tabWidth - (dropdownWidth - dropdown.width()) : 'auto';
      }
      
      dropdown.data('positioning:' + this.longTabs, css);
    }
    
    dropdown.css(dropdown.data('positioning:' + this.longTabs));
  },
    
  deleteFromDropdown: function (lis) {
    if (!lis.length) {
      return;
    }
    
    var ul = lis.parent();
    
    lis.remove();
    
    if (!ul.children().length) {
      ul.hide().prev('h4').hide();
    }
    
    // The ul variable will only have a visible ul sibling if there were bookmarks and history entries in this dropdown.
    // If not, hide the toggle arrow, and trigger the click event on it, which ensures the dropdown is hidden
    // and the arrow will be pointing the right way if it is shown again later
    if (!ul.siblings('ul:visible').length) {
      this.elLk.allTabs.filter(ul.parent().data('type')).find('.toggle').hide().first().trigger('click').end().parent().addClass('empty');
    } else {
      this.dropdownPosition(ul.parent(), this.elLk.allTabs.filter(ul.parent().data('type') + ':visible'), true);
    }
    
    lis = null;
    ul  = null;
  },
  
  deleteBookmark: function (id) {
    this.deleteFromDropdown($('.bookmarks .' + id, this.elLk.dropdowns).parent());
  },
  
  setWidth: function (type) {
    var panel = this;
    
    this.widths[type] = 0;
    this.widths[type + 'Array'] = [];
    
    this.elLk[type].each(function () {
      var w = $(this).outerWidth(true);
      panel.widths[type] += w;
      panel.widths[type + 'Array'].unshift(w);
    });
  },
  
  resize: function () {
    if (!this.widths) {
      return; // In IE7, resize is triggered in between constructor, where the event is registered, and init, where this.widths are set. Ignore this occurence of the event.
    }
    
    var panel       = this;
    var minWidth    = Ensembl.minWidthEl.outerWidth();
    var windowWidth = $(window).width();
    var threshold   = windowWidth < minWidth ? minWidth : windowWidth;
    var longTabs    = this.widths.longTabs < threshold;
    var shortTools  = this.widths.tools > threshold - this.widths.search - this.widths.logo;
    var holderWidth, i, left, tabs;

    if (longTabs !== this.longTabs) {
      if (longTabs) {
        this.elLk.shortTabs.hide();
        this.elLk.longTabs.show();
        tabs = this.elLk.longTabs;
      } else {
        this.elLk.shortTabs.show();
        this.elLk.longTabs.hide();
        tabs = this.elLk.shortTabs;
      }
      
      this.longTabs = longTabs;
      
      // Move any visible dropdowns to line up with the newly visible tabs
      this.elLk.dropdowns.filter(':visible').each(function () {
        panel.dropdownPosition($(this), tabs.filter($(this).data('type')));
      });
      
      tabs = null;
    }
    
    if (shortTools) {
      holderWidth = threshold - this.widths.search - this.widths.logo - this.widths.more;
      i           = this.widths.toolsArray.length;
      left        = 0;
      
      while (i--) {
        if (left + this.widths.toolsArray[i] > holderWidth) {
          this.elLk.toolsOverflow = this.elLk.tools.filter(':gt(' + (this.widths.toolsArray.length - i - 2) + ')');
          break;
        }
        
        left += this.widths.toolsArray[i];
      }
      
      this.elLk.toolsUl.width(holderWidth);
      this.elLk.toolMore.css('left', left).show();
      
      if (this.moreShown) {
        this.elLk.toolMoreUl.html(this.elLk.toolsOverflow.clone());
      }
    } else {
      this.elLk.tools.show();
      this.elLk.toolMore.hide();
      this.elLk.toolsUl.width('auto');
    }
  },
  
  hashChange: function (r, init) {
    var shortTab = this.elLk.shortTabs.filter('.location');
    var longTab  = this.elLk.longTabs.filter('.location');
    var recent   = Ensembl.speciesCommon + ': ' + Ensembl.lastR;
    var text     = r.split(/\W/);
        text     = 'Location: ' + text[0] + ':' + Ensembl.thousandify(text[1]) + '-' + Ensembl.thousandify(text[2]);
    
    shortTab.find('a:not(.toggle)').attr('title', text);
    longTab.find('a:not(.toggle)').html(text);
    
    // If there is a hash in the URL when the page is loaded, don't perform the following actions,
    // since the HTML will already be correct
    if (!init) {
      $.each([ shortTab, longTab ], function () {
        this.children('.dropdown').removeClass('empty').children('.toggle').show();
      });
      
      if (this.elLk.dropdowns.length && !this.recentLocations[recent]) {
        // Add the URL before the hash change to the top of the recent locations list
        this.elLk.dropdowns.filter('.location').find('ul.recent').prepend(
          '<li><a href="' + Ensembl.urlFromHash(window.location.href).replace(/([\?;]r=)[^;]+(;?)/, '$1' + Ensembl.lastR + '$2') + '">' + recent + '</a></li>'
        ).show().prev('h4').show();
        
        this.recentLocations[recent] = 1;
      }
    }
  }
});
