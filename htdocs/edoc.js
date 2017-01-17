/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2017] EMBL-European Bioinformatics Institute
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

var this_method;

function toggle_method(method) {
  if ($(method).style.display == 'none') {
    display_method(method);
  } else {
    hide_method(method);
  }
}

function hide_method(method) {
  $(method).hide();
  $(method + "_link").innerHTML = "View source";
}

function display_method(method) {
  this_method = method;
  var ajax_panel = new Ajax.Request("/common/highlight_method/" + method, { method: 'get', parameters: "", onComplete: code_loaded });
}

function code_loaded(response) {
  $(this_method).innerHTML = response.responseText;
  $(this_method).show();
  $(this_method + "_link").innerHTML = "Hide source";
}
