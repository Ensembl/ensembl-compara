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
 * filterableDropdown: Javascript counterpart for E::W::Form::Element::Filterable
 * Reserverd classname prefix: _fd
 **/
(function ($) {
  $.fn.filterableDropdown = function (options) {
  /*
   * options: object with following keys
   *   refresh  - To refresh the tags selected in an already instantiated object (this is useful in case some external code has modified the selected inputs)
   *   change   - Function to be called with the raw html as context, when changing the selection. This gets fired after dropdown is closed and tags are refreshed according to new selection
   */

    return this.each(function () {
      $.filterableDropdown($(this), options);
    });
  };

  $.filterableDropdown = function (el, options) {

    options = $.extend({}, options);

    // if already instantiated
    if (el.data('filterableDropdown')) {
      if (options.change) {
        el.off('afterAddRemove.filterableDropdown').on('afterAddRemove.filterableDropdown', options.change);
      }
      if (options.refresh) {
        el.trigger('open').trigger('close').find('label').trigger('refresh');
      }
      return;
    }

    el.on({
      'focusInput.filterableDropdown': function() {
        el.find('._fd_filter input').trigger('focus');
      },
      'open.filterableDropdown': function() {
        if (!el.data('filterableDropdown').closed) {
          return;
        }
        el.data('filterableDropdown').closed = false;
        el.addClass('open').find('._fd_filter').show().find('input').trigger('focus').trigger('keyup').next().html('&#9650;');
        $(document).off('.filterableDropdown').on('mousedown.filterableDropdown', function() {
          el.trigger('close');
        });
      },
      'close.filterableDropdown': function() {
        var tag = el.data('filterableDropdown').tag;
        var inp = el.find('input[type=checkbox]:checked, input[type=radio]:checked');
        el.data('filterableDropdown').closed = true;
        el.removeClass('open').find('._fd_tag').remove().end().find('._fd_filter input').trigger('reset').next().html('&#9660;').end().end().prepend(inp.map(function() {
          return tag.clone().data('input', this).show().find('span').first().html(this.nextSibling.innerHTML).end().end();
        }).toArray()).trigger('afterAddRemove');
        if (inp.length && inp.prop('type') === 'radio') {
          el.find('._fd_filter').hide();
        }
        $(document).off('.filterableDropdown');
        tag = inp = null;
      },
      'afterAddRemove.filterableDropdown': options.change || $.noop
    }).on('click', '._fdt_button', function() {
      var inp = $($(this).parent().data('input'));
      $(this.parentNode).remove();
      if (inp.prop('type') === 'checkbox') {
        inp.prop('checked', false);
        labels.trigger('refresh');
        el.trigger('afterAddRemove');
      } else {
        el.trigger('open');
      }
      inp = null;
    }).children().on({
      'mousedown.filterableDropdown': function(e) {
        e.stopPropagation(); // prevent closing if the dropdown if clicked inside the dropdown
      }
    }).find('input[type=checkbox], input[type=radio]').on({
      'keydown.filterableDropdown': function(e) {
        e.preventDefault(); // prevent the submission of form when pressed enter on the checkboxes
      },
      'click.filterableDropdown': function(e) {
        if (e.originalEvent) { // in other scenarios, afterClick is triggered explicitly
          $(this).triggerHandler('afterClick', this.type !== 'radio' && (e.metaKey || e.ctrlKey));
        }
      },
      'afterClick.filterableDropdown': function(e, multiSelect) {
        labels.trigger('refresh');
        el.trigger(multiSelect ? 'focusInput' : 'close');
      }
    });

    var labels = el.find('label').on({
      'mouseenter.filterableDropdown': function() {
        labels.removeClass('highlight');
        $(this).addClass('highlight');
      },
      'refresh.filterableDropdown': function() {
        $(this).toggleClass('selected', $(this.parentNode).find('input').prop('checked'));
      },
      'click.filterableDropdown': function(e) {
        var inp = $(this).parent().find('input');
        if (inp.prop('type') !== 'radio' && (e.metaKey || e.ctrlKey)) {
          e.preventDefault();
          inp.prop('checked', function() { return !this.checked }).triggerHandler('afterClick', true);
        }
        inp = null;
      }
    }).trigger('refresh');

    el.find('._fd_filter input').on({
      'focus.filterableDropdown': function() {
        if (this.value == this.defaultValue) {
          $(this).val('');
        }
        el.trigger('open');
      },
      'reset.filterableDropdown': function() {
        $(this).val(this.defaultValue).trigger('keyup').trigger('blur');
      },
      'keyup.filterableDropdown mouseup.filterableDropdown': function(e) {
        var value = this.value;
        if (e.originalEvent && (value === this.defaultValue || e.which === 38 || e.which === 40 || e.which === 13 || el.data('filterableDropdown').previousValue === value)) {
          return false;
        }
        el.data('filterableDropdown').previousValue = value;
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
        el.find('._fd_nomatch').toggle(!labels.filter(':visible').parent().removeClass('first-child last-child').first().addClass('first-child').end().last().addClass('last-child').end().length);
        labels.parent().parent().scrollTop(0);
      },
      'keydown.filterableDropdown paste.filterableDropdown': function(e) {
        var labelsReverse, found = false;
        switch (e.which) {
          case 13:
            e.preventDefault();
            var inp = labels.filter('.highlight:visible').parent().find('input');
            if (inp.prop('type') !== 'radio' && (e.metaKey || e.ctrlKey)) {
              inp.prop('checked', true).triggerHandler('afterClick', true);
            } else {
              // triggering the click event actually sets the checked prop to true along with firing any other attached click events
              inp.prop('checked', false).trigger('click').triggerHandler('afterClick', false);
            }
            inp = null;
          break;
          case 9:
          case 27:
            el.trigger('close');
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
                if (found) {
                  var p       = label.parent();
                  var div     = p.parent();
                  var pH      = p.height();
                  var divH    = div.height();
                  var scroll  = p.offset().top - div.offset().top - 1;
                  if (scroll > 0) {
                    scroll = scroll + pH - divH;
                    if (scroll < 0) {
                      scroll = 0;
                    }
                  }
                  if (scroll) {
                    div.scrollTop(div.scrollTop() + scroll);
                  }
                  p = div = pH = divH = scroll = null;
                }
                found = false;
              }
            }).filter('.highlight').length) {
              (labelsReverse || labels).filter(':visible').last().addClass('highlight');
            }
          break;
          default:
            if (!this.value || this.value == this.defaultValue) {
              $(this).val('');
            }
          break;
          labelsReverse = found = null;
        }
      }
    }).next().on({
      'click.filterableDropdown': function(e) {
        el.trigger(el.data('filterableDropdown').closed ? 'open' : 'close');
      }
    });

    el.data('filterableDropdown', {tag: el.find('._fd_tag').remove()}).trigger('close');
  };
})(jQuery);
