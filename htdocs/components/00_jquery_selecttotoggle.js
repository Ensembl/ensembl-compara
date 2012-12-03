/**
 * selectToToggle - Show/hide an HTML block(s) according to value selected in a <select>, or <input type="radio"> element
 * Reserved JS class prefix: _stt
 * Reserved CSS class prefix: none
 * Note: Be careful if there are more than one selectToToggle elements on a page with one or more options having same values (use className on the option tags in those cases)
 **/
(function ($) {
  $.selectToToggle = function (el, toggleMap, wrapper) {
    
    var toggle = function() {
      for (var val in toggleMap) {
        if (val != this.value) {
          wrapper.find(toggleMap[val]).hide().removeAttr('selected checked').filter('option').each(function() { // if hiding an option element, also disable it to make it work in webkit
            var option = $(this);
            if (typeof option.data('_stt_disabled') === 'undefined') {
              option.data('_stt_disabled', !!this.disabled); // remember original disabled attribute
            }
          }).attr('disabled', true);
        }
      }

      wrapper.find(toggleMap[this.value]).show().filter('option').attr('disabled', function() {
        return $(this).data('_stt_disabled');
      }).filter('select option').parent().each(function() { //show the requried html block
        var dropdown = $(this);
        if (!dropdown.find('option:selected:enabled').length) { //in case any selected option got hidden in this, select one of the visible ones
          dropdown.find('option:enabled').first().attr('selected', true);
        }
      });
    };

    el.on('change.selectToToggle', toggle);
    if (el[0].nodeName == 'SELECT' || el[0].checked) {
      toggle.apply(el[0]);
    }
  };

  $.fn.selectToToggle = function (
    toggleMap,  // map of select element's option value to corresponding jquery selectors strings (as accepted by find() method) (Optional - defaults to '._stt_[className]' if class name uses prefix _stt__, or '._stt_[value]' otherwise)
    wrapper     // wrapper element to call method 'find(selectors)' on - defaults to $(document.body)
  ) {
    
    return this.each(function () {
      var input = $(this);
      var tMap  = $.extend({}, toggleMap);
      wrapper   = wrapper || $(document.body);
      if ($.isEmptyObject(tMap)) {
        (this.nodeName == 'SELECT' ? input.find('option') : wrapper.find('input[name=' + this.name + ']')).each(function() {
          if (this.value) {
            tMap[this.value] = '._stt_' + ((this.className.match(/(?:\s+|^)_stt__([^\s]+)/) || []).pop() || this.value);
          }
        });
      }
      $.selectToToggle(input, tMap, wrapper);
    });
  };
})(jQuery);