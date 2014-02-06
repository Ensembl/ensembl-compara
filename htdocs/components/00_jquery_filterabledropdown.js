/*
 * Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
 * filterableDropdown: Javascript counterpart for E::W::Form::Element::Filterable
 * Reserverd classname prefix: _fd
 **/
(function ($) {
  $.fn.filterableDropdown = function () {

    return this.each(function () {
      $.filterableDropdown($(this));
    });
  };

  $.filterableDropdown = function (el) {

    if (el.data('filterableDropdown')) { // reset if already existing
      el.find('._fd_filter input').each(function() {
        this.value = this.defaultValue;
      }).trigger('keyup').trigger('blur');
      return;
    }

    // prevent the submission of form when pressed enter on the checkboxes
    el.find('input[type=checkbox]').on('keydown', function(e) { e.preventDefault(); });

    // hover effect for the labels
    var labels = el.find('label').on('mouseenter', function() {
      labels.removeClass('highlight');
      $(this).addClass('highlight');
    });
    el.find('._fd_filter input').on({
      'focus': function() {
        if (this.value == this.defaultValue) {
          $(this).selectRange(0, 0);
        }
      },
      'blur': function() {
        if (!this.value || this.value == this.defaultValue) {
          $(this).addClass('inactive').val(this.defaultValue);
        }
      },
      'keyup mouseup': function(e) {
        if (this.value == this.defaultValue || e.which == 38 || e.which == 40 || e.which == 13) {
          return false;
        }
        var value = this.value;
        labels.each(function() {
          var label       = $(this);
          this.innerHTML  = label.text(); // remove any previously added <span>
          if (value.match(/^[a-z\s]+$/i)) {
            label.parent().hide();
            this.innerHTML = this.innerHTML.replace(new RegExp("(^|[^a-z]{1})(" + value + ")", 'i'), function() {
              label.parent().show();
              return arguments[1] + '<span class="highlight">' + arguments[2] + '</span>';
            });
          } else {
            label.parent().show();
            labels.removeClass('highlight');
          }
        });
        if (!labels.filter('.highlight:visible').length) {
          labels.removeClass('highlight').filter(':visible').first().addClass('highlight');
        }
      },
      'keydown paste': function(e) {
        var labelsReverse, found = false;
        switch (e.which) {
          case 13:
            e.preventDefault();
            labels.filter('.highlight:visible').parent().find('input').each(function() { this.checked = !this.checked; }); // any toggleProp method?
          break;
          case 38:
            labelsReverse = $(labels.get().reverse());
          case 40:
            e.preventDefault();
            if (!(labelsReverse || labels).filter(':visible').each(function() {
              var label = $(this);
              if (label.hasClass('highlight')) {
                label.removeClass('highlight');
                found = true;
              } else {
                label.toggleClass('highlight', found);
                found = false;
              }
            }).filter('.highlight').length) {
              (labelsReverse || labels).filter(':visible').last().addClass('highlight');
            }
          break;
          default:
            if (this.value == this.defaultValue) {
              $(this).removeClass('inactive').val('');
            }
          break;
        }
      }
    });

    el.data('filterableDropdown', true);
  };
})(jQuery);