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

/* We always display two either side of the current page, the first two,
 * and the last two. If there are gaps either side, add elipses. 
 */

(function($) {
  $.fn.newtable_pager = function(config,data,widgets) {
    var show_initial_pages = 2;
    var show_total_pages = 10;
    var show_final_pages = 2;
    var rows_per_page = 10;

    function which_links_to_show(cur,num) {
      var i;

      var pages = [];
      // Current page and after
      for(i=0;i<show_total_pages && i+cur<num;i++) { pages.push(cur+i); }
      // Before current page
      for(i=0;(pages.length<show_total_pages || i<show_initial_pages+2) && cur>i;i++) {
        pages.unshift(cur-i-1);
        if(pages.length>show_total_pages) { pages.pop(); }
      }

      // Start
      if(pages[0]!==0) {
        for(i=0;i<show_initial_pages+1;i++) { pages.shift(); }
        pages.unshift(-1);
        for(i=0;i<show_initial_pages;i++) {
          pages.unshift(show_initial_pages-i-1);
        }
      }
      // End
      if(pages[pages.length-1]!=num-1) {
        for(i=0;i<show_final_pages+1;i++) { pages.pop(); }
        pages.push(-1);
        for(i=0;i<show_final_pages;i++) {
          pages.push(num-show_final_pages+i);
        }
      }
      return pages;
    }

    function set_page($table,num) {
      var view = $table.data('view');
      view.pagerows = [num*rows_per_page,(num+1)*rows_per_page];
      $table.data('view',view).trigger('view-updated');
    }

    function pager_click() {
      var idx = parseInt($(this).attr('href').substring(1));
      set_page($table,idx);
      e.stopPropagation();
    }

    function draw_pager($table,cur,num) {
      var $ul = $('.newtable_pager',$table).empty();
      var pages = which_links_to_show(cur,num);
      for(var i=0;i<pages.length;i++) {
        if(pages[i]==-1) {
          $('<li/>').text('...').appendTo($ul);
        } else if(pages[i]==cur) {
          $('<li/>').text(cur+1).appendTo($ul);
        } else {
          var $a = $('<a href="#'+pages[i]+'"/>').text(pages[i]+1);
          $a.on('click',pager_click);
          $('<li/>').append($a).appendTo($ul);
        }
      }
    }

    return {
      generate: function() {
        var out = '<ul class="newtable_pager"></ul>';
        return out;
      },
      go: function($table,$el) {
      },
      position: data.position,
      size: function($table,len) {
        var rows = $table.data('view').pagerows;
        $('.newtable_pager',$table).empty();
        if(rows && len) {
          var cur = rows[0]/rows_per_page;
          var num = Math.floor((len+rows_per_page-1)/rows_per_page);
          if(cur<num) {
            draw_pager($table,cur,num);
          }
        }
      }
    };
  }; 

})(jQuery);
