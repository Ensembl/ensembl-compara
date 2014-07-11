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
  $(function() {
    $.fn.toggleButtons = function () {
      return this.each(function () {
        var $this = $(this);
        $this.click(function() {
          $this.toggleClass('off');
          var url = $this.attr('href');
          if(url) {
            $.ajax({
              url: url,
              type: 'POST',
              traditional: true,
              cache: false,
              context: this,
              dataType: 'json',
              data: {
                state: $this.hasClass('off')?0:1
              }
            }).fail(function() {
              $this.toggleClass('off');
            }).done(function(data) {
              if(data.reload_panels) {
                $.each(data.reload_panels,function(i,panel) {
                  Ensembl.EventManager.triggerSpecific('updatePanel',panel);
                });
              }
            });
          }
          return false;
        });
      });
    };
  });
})(jQuery);
