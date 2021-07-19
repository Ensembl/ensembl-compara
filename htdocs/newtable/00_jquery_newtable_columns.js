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
  $.fn.new_table_columns = function(config,data,widgets,callw) {

    function update_ticks($table,$popup) {
      var view = $table.data('view');
      var off_columns = view.off_columns;
      $('li input',$popup).each(function() {
        var $input = $(this);
        $input.prop('checked',!off_columns || !off_columns[$input.data('key')]);
      });
    }

    function record_ticks($table,$popup) {
      var off_columns = {};
      $('li input',$popup).each(function() {
        var $input = $(this);
        off_columns[$input.data('key')] = !$input.prop('checked');
      });
      var view = $table.data('view');
      view.off_columns = off_columns;
      $table.data('view',view).trigger('view-updated');
    }

    var record_ticks_soon = $.debounce(function($table,$popup) {
      record_ticks($table,$popup);
    },1000);

    return {
      generate: function() {
        var out = '<div class="col_toggle"><div class="toggle">'+
                  'Show/hide columns'+
                  '<ul class="floating_popup">';
        $.each(config.columns,function(i,key) {
          var cc = config.colconf[key];
          if(callw('unshowable',cc)._any) { return; }
          var label = cc.label || key;
          out += '<li><input type="checkbox" data-key="'+key+'">'+
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
          record_ticks_soon($table,$popup);
          return false;
        });
        $('input',$popup).click(function(e) {
          record_ticks_soon($table,$popup);
          e.stopPropagation();
        });
        update_ticks($table,$popup);
      },
      position: data.position,
      pipe: function() {
        return [
          function(need,got) {
            if(!got) { return null; }
            var ok = true;
            $.each(got.off_columns||{},function(k,v) {
              if(!need.off_columns[k] && got.off_columns[k]) { ok = false; }
            });
            var old_columns = need.off_columns;
            if(ok) { need.off_columns = got.off_columns; }
            return {
              undo: function(manifest,grid) {
                manifest.off_columns = old_columns;
                return [manifest,grid];
              }
            };
          }
        ];
      }
    };
  }; 

})(jQuery);
