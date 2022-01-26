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
  var ajax_pending = [];
  var ajax_running = 0;
  var max_ajax_running = $('body').data('pace') || 2;

  function fire_paced_ajax() {
    if(!ajax_pending.length || ajax_running >= max_ajax_running) {
      return;
    }
    var task = ajax_pending.shift();
    ajax_running += 1;
    $.ajax(task[0]).always(function(data) {
      ajax_running--;
      fire_paced_ajax();
    }).done(function(data) {
      task[1].resolve(data);
    }).fail(function(data) {
      task[1].reject(data);
    });
  }

  function paced(conf) {
    e = $.Deferred();
    ajax_pending.push([conf,e]);
    fire_paced_ajax();
    return e;
  }

  $.extend({ paced_ajax: paced });
})(jQuery);


