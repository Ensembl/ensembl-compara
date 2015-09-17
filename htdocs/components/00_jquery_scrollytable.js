/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
  $.fn.scrollyTable = function () {

    return this.hasClass('_scrollytable_active') ? this : this.wrap('<div style="overflow:auto">').parent().on('scroll.scrollyTable', function () {
      $(this.previousSibling).scrollLeft($(this).scrollLeft());
    }).before('<div style="overflow:auto"><div style="height:1px;margin-top:-1px"></div></div>').prev().on('scroll.scrollyTable', function () {
      $(this.nextSibling).scrollLeft($(this).scrollLeft());
    }).children().width(this.outerWidth()).end().filter(function () {
      return !!$(this).outerHeight();
    }).children().helptip({
      content   : 'Scroll to see more columns &raquo;',
      position  : { my: 'right-20 top+12', at: 'left+' + this.parent().width() + ' top' },
      open      : function (e, ui) { ui.tooltip.css('cursor', 'default').one('click', function () { $(this).fadeOut(); }); },
      hide      : 400
    }).helptip('open').end().one('scroll.scrollyTable', function () {
      $(this).children().helptip('close');
    }).end().end().end().addClass('_scrollytable_active');
  };
})(jQuery);
