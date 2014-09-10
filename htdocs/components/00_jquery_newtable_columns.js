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
  $.fn.new_table_columns = function(config,data) {

    function update_ticks($table,$popup) {
      var view = $table.data('view');
      var columns = view.columns;
      $('li input',$popup).each(function() {
        var $input = $(this);
        $input.prop('checked',!columns || columns[$input.data('key')]);
      });
    };

    function record_ticks($table,$popup) {
      var columns = [];
      $('li input',$popup).each(function() {
        var $input = $(this);
        columns[$input.data('key')] = $input.prop('checked');
      });
      var view = $table.data('view');
      view.columns = columns;
      $table.data('view',view).trigger('view-updated');
    };

    return {
      generate: function() {
        var out = '<div class="col_toggle"><div class="toggle">'+
                  'Show/hide columns'+
                  '<ul class="floating_popup">';
        $.each(config.columns,function(i,col) {
          var label = col.label || col.key;
          out += '<li><input type="checkbox" data-key="'+i+'">'+
                 '<span>'+label+'</span></li>';
        });
        out += '</ul></div></div>';
        return out;
      },
      go: function($table,$el) {
        var $button = $('.toggle',$el);
        var $popup  = $('.floating_popup',$el);
        $button.click(function() { $popup.toggle(); });
        $table.on('view-updated',function() {
          update_ticks($table,$popup);
        });
        $('li',$popup).click(function() {
          var $input = $('input',this);
          $input.prop('checked',!$input.prop('checked'));
          record_ticks($table,$popup);
          return false;
        });
        $('input',$popup).click(function(e) {
          record_ticks($table,$popup);
          e.stopPropagation();
        });
        update_ticks($table,$popup);
      }
    };
  }; 

})(jQuery);
