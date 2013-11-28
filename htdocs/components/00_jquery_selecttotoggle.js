/*
 * Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

/**
 * selectToToggle - Show/hide an HTML block(s) according to value selected in a <select>, or <input type="radio"> element
 * Reserved JS class prefix: _stt
 * Reserved CSS class prefix: none
 * Note: Be careful if there are more than one selectToToggle elements on a page with one or more options having same values (use className on the option tags in those cases)
 **/
(function ($) {
  $.selectToToggle = function (el, options, wrapper) {
    var toggle = function () {
      for (var val in options) {
        if (val != this.value) {
          wrapper.find(options[val]).hide().removeAttr('selected checked').filter('option').each(function() { // if hiding an option element, also disable it to make it work in webkit
            var option = $(this);
            
            if (typeof option.data('_stt_disabled') === 'undefined') {
              option.data('_stt_disabled', !!this.disabled); // remember original disabled attribute
            }
          }).prop('disabled', true);
        }
      }

      wrapper.find(options[this.value]).show().filter('option').prop('disabled', function() {
        return $(this).data('_stt_disabled');
      }).filter('select option').parent().each(function() { //show the requried html block
        var dropdown = $(this);
        if (!dropdown.find('option:selected:enabled').length) { //in case any selected option gets hidden in this, select the first visible option
          dropdown.find('option:enabled').first().prop('selected', true);
        }
      });
    };

    if (options === 'trigger') {
      el.trigger('change.selectToToggle');
    } else {
      el.off('.selectToToggle').on('change.selectToToggle', toggle);
      
      if (el[0].nodeName == 'SELECT' || el[0].checked) {
        toggle.apply(el[0]);
      }
    }
  };

  $.fn.selectToToggle = function (
    options,    // string 'trigger' to trigger toggling for an existing element, or map of select element's option value to corresponding jquery selectors strings (as accepted by find() method) (Optional - defaults to '._stt_[className]' if class name uses prefix _stt__, or '._stt_[value]' otherwise)
    wrapper     // wrapper element to call method 'find(selectors)' on - defaults to $(document.body)
  ) {
    
    return this.each(function () {
      var input = $(this);
      
      if (options === 'trigger') {
        $.selectToToggle(input, 'trigger', wrapper);
      } else {
        var tMap  = $.extend({}, options);
        wrapper   = wrapper || $(document.body);
        
        if ($.isEmptyObject(tMap)) {
          (this.nodeName == 'SELECT' ? input.find('option') : wrapper.find('input[name=' + this.name + ']')).each(function() {
            if (this.value) {
              tMap[this.value] = '._stt_' + ((this.className.match(/(?:\s+|^)_stt__([^\s]+)/) || []).pop() || this.value);
            }
          });
        }
        
        $.selectToToggle(input, tMap, wrapper);
      }
    });
  };
})(jQuery);