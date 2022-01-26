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

/**
 * scrollyTable - Displays horizotal scollbars for a wide table
 **/
(function ($) {
  $.fn.scrollyTable = function (
    action /* null to initialise, 'refresh' to refresh the top scrollbar length or 'destroy' to remove the the horizontal scrollbars completely */
  ) {

    return this.each(function() {

      var id;
      var el = $(this);

      if (id = (this.className.match(/_scrollytable_id_[0-9]+/) || []).pop()) {

        switch (action) {
          case 'refresh':
            el.parent().prev().children().width(el.outerWidth()).filter(function () {
              return $(this.parentNode).outerHeight() < 1 && !!$(this).data('uiTooltip');
            }).helptip('close');
          break;

          case 'destroy':
            el.removeClass(id).parent().prev().remove().end().replaceWith(el);
            $(window).off('.' + id);
          break;
        }
      } else if (!action) {

        id = Math.random().toString().replace('0.', '_scrollytable_id_');

        el.addClass(id).wrap('<div style="overflow:auto">').parent().on('scroll.scrollyTable', function () {
          $(this.previousSibling).scrollLeft($(this).scrollLeft());
        }).before('<div style="overflow:auto"><div style="height:1px"></div></div>').prev().on('scroll.scrollyTable', function () {
          $(this.nextSibling).scrollLeft($(this).scrollLeft());
        }).children().width(el.outerWidth()).end().filter(function () {
          return $(this).outerHeight() >= 1;
        }).children().helptip({
          content   : 'Scroll to see more columns &raquo;',
          position  : { my: 'right-20 top+12', at: 'left+' + el.parent().width() + ' top' },
          open      : function (e, ui) { ui.tooltip.css('cursor', 'default').one('click', function () { $(this).fadeOut(); }); },
          hide      : 400
        }).helptip('open').end().one('scroll.scrollyTable', function () {
          $(this).children().helptip('close');
        });

        // refresh on window resize
        $(window).on('resize.' + id, {el : this}, function(e) {
          $(e.data.el).scrollyTable('refresh');
        });

        // refresh on add/remove column from DataTable
        if (el.hasClass('data_table')) {
          el.dataTable().fnSettings().aoDrawCallback.push({
            'fn': function () {
              this.scrollyTable('refresh');
            }
          });
        }
      }

      el = null;
    });

  };
})(jQuery);
