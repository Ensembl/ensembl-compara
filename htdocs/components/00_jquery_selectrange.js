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

(function ($) {
  $.fn.selectRange = function(start, end) {
    return this.filter(':visible').each(function() {

      var _start = typeof start === 'function' ? start.call(this) : start;
      var _end = typeof end === 'function' ? end.call(this) : end;

      if (this.setSelectionRange) {
        this.focus();
        this.setSelectionRange(_start, _end);

      } else if (this.createTextRange) {
        var range = this.createTextRange();
        range.collapse(true);
        range.moveEnd('character', _end);
        range.moveStart('character', _start);
        range.select();
      }
    }).end();
  };
})(jQuery);