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

(function($) {
  $.fn.newtable_diagonal = function(config,data,widgets,callw) {
    function decorate_fn(column,extras,series) {
      return {
        go: function(html,row) {
          return '<div style="text-align: center">'+html+'</div>';
        }
      }
    }

    var decorators = {};
    $.each(config.colconf,function(key,cc) {
      if(cc.heading && cc.heading.diagonal) {
        decorators[key] = [decorate_fn];
      }
    });

    return {
      prio: 75,
      decorate_heading: function(cc,$th,first,html) {
        if(html===undefined) { html = first; }
        if(cc.heading && cc.heading.diagonal) {
          var $span = $('<span/>').html(html).addClass('newtable_diagonal');
          $th.addClass('newtable_diagonal_th');
          return $('<div/>').append($span).html();
        } else {
          $th.addClass('newtable_not_diagonal_th');
          return html;
        }
      },
      decorators: { diagonal: decorators }
    };
  }; 
})(jQuery);
