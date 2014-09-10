/*
 * Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
  $.fn.new_table_filter = function(config,data) {
    return {
      generate: function() {
        return '<input class=""/>';
      },
      go: function($table,$el) {
        var $input = $('input',$el);
        var view = $table.data('view');
        if(view.hasOwnProperty('filter')) {
          $input.val(view.filter);
        }
        $input.on("propertychange keyup input paste",function() {
          var view = $table.data('view');
          view.filter = $input.val();
          $table.data('view',view);
          $table.trigger('view-updated');
        });
      }
    };
  }; 

})(jQuery);
