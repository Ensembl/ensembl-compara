/**
 * selectToToggle - Show/hide an HTML block(s) according to value selected in a <select> element
 * Reserved JS class prefix: _stt
 * Reserved CSS class prefix: none
 * Note: Be careful if there are more than one selectToToggle elements on a page with one or more options having same values (use className on the option tags in those cases)
 **/
(function ($) {
  $.selectToToggle = function (el, toggleMap, wrapper) {
    
    el.on('change.selectToToggle', function() {
      for (var val in toggleMap) {
        wrapper.find(toggleMap[val]).hide();
      }
      wrapper.find(toggleMap[this.value]).show();
    });
  };

  $.fn.selectToToggle = function (
    toggleMap,  // map of select element's option value to corresponding jquery selectors strings (as accepted by find() method) (Optional - defaults to '._stt_[className]' if class name uses prefix _stt__, or '._stt_[value]' otherwise)
    wrapper     // wrapper element to call method 'find(selectors)' on - defaults to $(document.body)
  ) {
    
    return this.each(function () {
      var select  = $(this);
      var tMap    = $.extend({}, toggleMap);
      if ($.isEmptyObject(tMap)) {
        select.find('option').each(function() {
          if (this.value) {
            tMap[this.value] = '._stt_' + ((this.className.match(/(?:\s+|^)_stt__([^\s]+)/) || []).pop() || this.value);
          }
        });
      }
      $.selectToToggle(select, tMap, wrapper || $(document.body));
    });
  };
})(jQuery);