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

/**
 * selectToToggle - Show/hide an HTML block(s) according to value selected in a <select>, or <input type="radio|checkbox"> element
 * Reserved JS class prefix: _stt
 * Reserved CSS class prefix: none
 * Note: Be careful if there are more than one selectToToggle elements on a page with one or more options having same values (use className on the option tags in those cases)
 **/
(function ($) {
  $.selectToToggle = function (el) {
    var toggle = function () {
      var data      = $(this).data('selectToToggle');
      var wrapper   = data.wrapper;
      var toggleMap = data.toggleMap;
      var currValue = this.nodeName === 'INPUT' && this.type === 'checkbox' && !this.checked ? false : this.value; // if checkbox is not ticked, ignore it's value

      // go through all the selectors in the toggleMap and hide them except the one that corresponds to current element's value
      for (var val in toggleMap) {
        if (val !== currValue) {
          wrapper.find(toggleMap[val]).hide().removeAttr('checked').filter('option').each(function() { // if hiding an option element, also disable it to make it work in webkit
            var option = $(this);

            if (typeof option.data('sttDisabled') === 'undefined') {
              option.data('sttDisabled', !!this.disabled); // remember original disabled attribute
            }
          }).prop('disabled', true);
        }
      }

      // show the html block corresponsing to current element's value
      wrapper.find(toggleMap[currValue]).show().filter('option').prop('disabled', function() {
        return $(this).data('sttDisabled');
      }).filter('select option').parent().each(function() {
        var dropdown = $(this);
        if (!dropdown.find('option:selected:enabled').length) { //in case any selected option gets hidden in this, select the first visible option
          dropdown.find('option:enabled').first().prop('selected', true);
          if (dropdown.data('selectToToggle')) {
            dropdown.trigger('change.selectToToggle');
          }
        }
      });
    };

    el.off('.selectToToggle').on('change.selectToToggle', toggle).filter('select, input:checked').first().triggerHandler('change.selectToToggle');
  };

  $.fn.selectToToggle = function (
    toggleMap,  // map of select element's option value to corresponding jquery selectors strings (as accepted by find() method) (Optional - defaults to '._stt_[className]' if class name uses prefix _stt__, or '._stt_[value]' otherwise)
                // string 'trigger' to trigger toggling for an existing element (this is useful is option is selected by JS)
                // string 'destroy' to remove all selectToToggle data and events from the element
    wrapper     // wrapper element to call method 'find(selectors)' on - defaults to $(document.body)
  ) {
    
    return this.each(function () {
      var el        = $(this);
      var data      = el.data('selectToToggle');

      var getAllEls = function(el, wrapper) {
        return el[0].nodeName === 'INPUT' ? wrapper.find('input[name=' + el[0].name + ']') : el;
      };

      if (data) {
        if (toggleMap === 'trigger') {
          if (el[0].nodeName === 'SELECT' || el[0].checked) {
            el.trigger('change.selectToToggle');
          }
        } else if (toggleMap === 'destroy') {
          getAllEls(el, data.wrapper).off('.selectToToggle').removeData('selectToToggle');
        }

      } else {
        var tMap  = $.extend({}, toggleMap);
        wrapper   = wrapper || $(document.body);
        el        = getAllEls(el, wrapper);

        if ($.isEmptyObject(tMap)) {
          (this.nodeName == 'SELECT' ? el.find('option') : el).each(function() {
            if (this.value) {
              var filters = $.map(this.className.match(/(\s+|^)_stt__([^\s]+)/g) || [], function(str) { return str.replace('_stt__', '._stt_') });
                  filters.push('._stt_' + this.value);
              tMap[this.value] = this.className.match(/(\s+|^)_sttmulti($|\s+)/) ? filters.join(',') : filters[0];
            }
          });
        }

        el.data('selectToToggle', {'wrapper' : wrapper, 'toggleMap': tMap});

        $.selectToToggle(el);
      }
    });
  };
})(jQuery);