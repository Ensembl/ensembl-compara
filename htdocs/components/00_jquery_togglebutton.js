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
  function to_server(url,state) {
    return $.ajax({
      url: url,
      type: 'POST',
      traditional: true,
      cache: false,
      context: this,
      dataType: 'json',
      data: { state: state }
    }).fail(function() {
      $this.toggleClass('off');
    });
  };

  function fix_radio($this) {
    var $group = $this.parent('.group');
    var radio = $('a.togglebutton.radiogroup',$group).length;
    if(radio && $('a.togglebutton:not(.off)',$group).length < 2) {
      $('a.togglebutton:not(.off)',$group).addClass('inactive');
    } else {
      $('a.togglebutton',$group).removeClass('inactive');
    }
  };

  $.fn.toggleButtons = function () {
    return this.each(function () {
      var $this = $(this);
      var $group = $this.parent('.group');
      var radio = $('a.togglebutton.radiogroup',$group).length;
      fix_radio($this);

      $this.click(function() {
        if($this.hasClass('inactive') || $this.hasClass('disabled')) {
          return false;
        }
        $this.toggleClass('off');
        fix_radio($this);
        var state = $this.hasClass('off')?'0':'1';

        var url = $this.attr('href');
        if(url) {
          to_server(url,state).done(function(data) {
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
})(jQuery);
