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
  $.fn.newtable_frame_default = function(config,data) {

    return {
      frame: function($html) {
        // XXX cssclass
        var $out = $('<div class="new_table_wrapper"/>');
        var $toprow = $('<div class="new_table_top"/>').appendTo($out);
        var triptych = [];
        for(var pos=0;pos<3;pos++) {
          triptych[pos] =
            $('<div class="new_table_section new_table_section_'+pos+'"/>');
          triptych[pos].appendTo($toprow);
        }
        var $slices = $('<div/>').appendTo($out);
        var $before = $('<div class="before"/>');
        var $controller = $('<div class="newtable_controller"/>');
        $out.prepend($controller).prepend($before).append($html);
        return {
          '$': $out,
          'before': {
            'tags': ['before'],
            '$': $before
          },
          'controller': {
            'tags': ['controller','pre'],
            '$': $controller
          },
          'topper': {
            'tags': ['full','inner','full-inner','top-full-inner'],
            '$': $slices
          },
          'nw': {
            'tags': ['top','left','top-left'],
            '$': triptych[0]
          },
          'n': {
            'tags': ['top','middle','top-middle'],
            '$': triptych[1]
          },
          'ne': {
            'tags': ['top','right','top-right'],
            '$': triptych[2]
          }
        };
      }
    };
  }; 

})(jQuery);
