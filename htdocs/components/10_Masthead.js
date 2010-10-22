// $Revision$

Ensembl.Panel.Masthead = Ensembl.Panel.extend({
  constructor: function (id) {
    this.longTabs        = false;
    this.moreShown       = false;
    this.zIndex          = 1000;
    this.recentLocations = {};
  
    this.base(id);
    
    Ensembl.EventManager.register('windowResize',   this, this.resize);
    Ensembl.EventManager.register('hashChange',     this, this.hashChange);
    Ensembl.EventManager.register('deleteBookmark', this, this.deleteBookmark);
  },
  
  init: function () {
    var panel = this;
    
    this.base();
    
    var tabsHolder = $('.tabs_holder', this.el);
    var tabs       = $('.tabs', tabsHolder);
    var tools      = $('.tools_holder', this.el);
    var logo       = $('.logo_holder', this.el);
    
    this.elLk.allTabs    = $('li', tabs);
    this.elLk.shortTabs  = $('li.short_tab', tabs);
    this.elLk.longTabs   = $('li.long_tab', tabs);
    this.elLk.toolsUl    = $('.tools', tools);
    this.elLk.tools      = $('li', this.elLk.toolsUl);
    this.elLk.toolMore   = $('.more', tools);
    this.elLk.toolMoreUl = $('<ul class="more_tools" />').appendTo(this.elLk.toolMore);
    this.elLk.dropdowns  = $('div.dropdown', tabsHolder).bind('click', function () {
      $(this).css('zIndex', panel.zIndex++);
    });
    
    // Cache the text on the recent location links, to stop hash changes in the URL from duplicating entries in the menu
    this.elLk.dropdowns.filter('.location').find('ul.recent li a').each(function () {
      panel.recentLocations[$(this).text()] = 1;
    });
    
    // Send an ajax request to clear the user's history for a tab/dropdown
    $('a.clear_history', this.elLk.dropdowns).bind('click', function () {
      var li = $(this).parent();
      
      $.ajax({
        url: this.href,
        success: function () {
          var lis = li.siblings();
          
          li.remove();
          panel.deleteFromDropdown(lis);
          
          lis = null;
          li  = null;
        }
      });
      
      return false;
    });
    
    if (window.location.hash) {
      this.hashChange(Ensembl.urlFromHash(window.location.href, true), true);
    }
    
    // Show the relevant dropdown when a toggle link is clicked
    $('.toggle', tabs).bind('click', function () {
      var dropdown = panel.elLk.dropdowns.filter('.' + this.rel);
      
      panel.dropdownPosition(dropdown, $(this).parents('li'));
      dropdown.not(':visible').css('zIndex', panel.zIndex++).end().toggle(); 
      panel.elLk.allTabs.filter('.' + this.rel).find('a.toggle').html(dropdown.is(':visible') ? '&#9650;' : '&#9660;'); // Change the toggle arrow from up to down or vice versa
      dropdown.data('type', '.' + this.rel); // Cache the selector to find the tab for use later
      
      dropdown = null;
      
      return false;
    });
    
    this.elLk.toolMore.children('a').bind('click', function () {
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
    
    tabsHolder = null;
    tabs       = null;
    tools      = null;
    logo       = null;
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
    var panel = this;
    
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
    text         = 'Location: ' + text[0] + ':' + Ensembl.thousandify(text[1]) + '-' + Ensembl.thousandify(text[2]);
    
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
