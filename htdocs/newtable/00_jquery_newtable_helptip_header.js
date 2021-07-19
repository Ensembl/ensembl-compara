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
  $.fn.newtable_helptip_header = function(config,data,widgets,callw) {
    return {
      prio: 50,
      decorate_heading: function(cc,$th,first,html) {
        if(html===undefined) { html = first; }
        if(cc.help) {
          var help = $('<span class="ht _ht"/>').attr('title',cc.help).html(html);
          html = $('<div/>').append(help).html();
        }
        return html;
      }
    };
  }; 
})(jQuery);
