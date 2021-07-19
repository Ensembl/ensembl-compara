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

(function($) {
  $.fn.new_table_pagesize = function(config,data) {
    return {
      generate: function() {
        var out = 'Show <div class="new_table_pagesize new_table_widget">' +
               '<select size="1">';
        $.each(data.sizes,function(i,el) {
          var text = el;
          if(el===0) { text = "All"; el = -1; }
          out += '<option value="'+el+'">'+text+'</option>';
        });
        out += '</select></div> entries';
        return out;
      },
      go: function($table,$el) {
        var view = $table.data('view');
        if(view.hasOwnProperty('pagesize')) {
          $('option',$el).removeAttr('selected');
          $('option[value="'+view.pagesize+'"]',$el).attr('selected',true); 
        }
        $('select',$el).change(function() {
          var $option = $('option:selected',$(this));
          var view = $table.data('view');
          view.rows = [0,parseInt($option.val())];
          $table.data('view',view);
          $table.trigger('view-updated');
        });
      },
      position: data.position
    };
  }; 

})(jQuery);
