(function ($) {
  $.fn.paginate = function (options) {
    options = $.extend({
      itemContainer    : '.content',
      itemsPerPage     : 10,
      navPanel         : '.page_navigation',
      navInfo          : '.info_text',
      linksToDisplay   : 20,
      startPage        : 0,
      navLabelFirst    : 'First',
      navLabelPrev     : 'Prev',
      navLabelNext     : 'Next',
      navLabelLast     : 'Last',
      navOrder         : [ 'first', 'prev', 'num', 'next', 'last' ],
      navLabelInfo     : 'Showing {0}-{1} of {2} results',
      showFirstLast    : true,
      showAll          : false,
      abortOnSmallLists: false
    }, options);
    
    return this.each(function () {
      var container = $(this);
      var items     = container.find(options.itemContainer).children();
      var navPanels = container.find(options.navPanel);
      var navInfo   = container.find(options.navInfo);
      var data      = container.data('paginate');
      
      function jumpTo(page) {
        data.previousPage = data.currentPage;
        data.currentPage  = parseInt(page, 10);
        
        var start  = options.showAll ? 0 : data.currentPage * data.itemsPerPage;
        var length = items.hide().slice(start, start + data.itemsPerPage).show().length;
        var check  = data.previousPage >= data.currentPage;
        
        navPanels.each(function () {
          var el    = $(this);
          var links = el.children('.page_link');
          var first = links.first();
          var last  = links.last();
          
          links.removeClass('active_page').filter('[rel=' + data.currentPage + ']').addClass('active_page');
          
          if (links.filter('.active_page')[0].style.display === 'none') {
            links.hide().slice(data.currentPage + (check ? 0 : 1 - options.linksToDisplay), data.currentPage + (check ? options.linksToDisplay : 1)).show();
          }
          
          el.children('.more')[last[0].style.display  === 'none' ? 'show' : 'hide']();
          el.children('.less')[first[0].style.display === 'none' ? 'show' : 'hide']();
          el.children('.next_link,      .last_link')[last.hasClass('active_page')  ? 'addClass' : 'removeClass']('no_more');
          el.children('.previous_link, .first_link')[first.hasClass('active_page') ? 'addClass' : 'removeClass']('no_more');
          
          el = links = first = last = null;
        });
        
        navInfo.html(options.navLabelInfo.replace('{0}', start + 1).replace('{1}', start + length).replace('{2}', items.length));
      }
      
      if (options.abortOnSmallLists && options.itemsPerPage >= items.length) {
        return;
      }
      
      navPanels.add(navInfo)[options.showAll ? 'hide' : 'show']();
      
      if (data) {
        data.itemsPerPage = options.showAll ? items.length : options.itemsPerPage;
        return jumpTo(data.currentPage);
      }
      
      var pages = Math.ceil(items.length / options.itemsPerPage);
      var more  = '<span class="ellipse more">...</span>';
      var less  = '<span class="ellipse less">...</span>';
      var first = !options.showFirstLast ? '' : '<a class="first_link" href="">' + options.navLabelFirst + '</a>';
      var last  = !options.showFirstLast ? '' : '<a class="last_link" href="">'  + options.navLabelLast  + '</a>';
      var html  = '';
      
      for (var i = 0; i < options.navOrder.length; i++) {
        switch (options.navOrder[i]) {
          case 'first': html += first; break;
          case 'last' : html += last; break;
          case 'next' : html += '<a class="next_link" href="">'     + options.navLabelNext + '</a>'; break;
          case 'prev' : html += '<a class="previous_link" href="">' + options.navLabelPrev + '</a>'; break;
          case 'num'  : html += less;
            var current = 0;
            
            while (pages > current) {
              html += '<a class="page_link" href="" rel="' + current + '">' + (++current) + '</a>';
            }
            
            html += more;
            break;
          default: break;
        }
      }
      
      navPanels.html(html);
      
      data = {
        currentPage : 0,
        previousPage: 0,
        itemsPerPage: options.itemsPerPage,
        totalLinks  : navPanels.first().children('.page_link').length
      };
      
      options.linksToDisplay = Math.min(options.linksToDisplay, data.totalLinks);
      
      container.data('paginate', data);
      items.hide().slice(0, options.itemsPerPage).show();
      
      navPanels.each(function () {
        $(this).children('.page_link').hide().eq(options.startPage).addClass('active_page').end().slice(0, options.linksToDisplay).show();
      });
      
      navPanels.children('a').on('click', function () {
        var page;
        
        switch (this.className) {
          case 'last_link'    : page = data.totalLinks  - 1; break;
          case 'previous_link': page = data.currentPage - 1; break;
          case 'next_link'    : page = data.currentPage + 1; break;
          default             : page = this.rel || 0;        break;
        }
        
        jumpTo(page);
        
        return false;
      });
      
      jumpTo(options.startPage);
      
      container = null;
    });
  };
})(jQuery);