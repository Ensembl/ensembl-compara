/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
  Effect.BlindUp(method);
  $(method + "_link").innerHTML = "View source";
}

function display_method(method) {
  this_method = method;
  var url = "/common/highlight_method/" + method;
  var data = "";
  var ajax_panel = new Ajax.Request(url, {
                           method: 'get',
                           parameters: data,
                           onComplete: code_loaded,
                           onLoading: code_loading
                         });
}

function code_loaded(response) {
  $(this_method).innerHTML = response.responseText;
  Effect.BlindDown(this_method);
  $(this_method + "_link").innerHTML = "Hide source";
}

function code_loading(response) {
} 
