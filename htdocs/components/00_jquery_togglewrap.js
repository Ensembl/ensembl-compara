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

(function ($) {
  $.togglewrap = function (elements, arg) {
    function init() {
      elements.each(function () {
        var el = $(this);
        
        if (el.data('togglewrap')) {
          el = null;
          return;
        }
        
        if (this.nodeName === 'TABLE') {
          if (el.css('table-layout') !== 'fixed') {
            $('th, td', el).width(function (i, w) { return w; });
            el.css('table-layout', 'fixed');
          }
        }
        
        $(window).on('resize.togglewrap', function (e) {
          // jquery ui resizable events cause window.resize to fire (all events bubble to window)
          // if target has no tagName it is window or document. Don't resize unless this is the case
          if (!e.target.tagName) {
            update();
          }
        });

        var $img = el.find('.toggle_img');
        if(!$img.hasClass('_bound')) {
          el.on('click', '.height_wrap .toggle_img', function () {
            toggle($(this));
            return false;
          });
          $img.addClass('_bound');
        }
        el.find('.toggle_img').addClass('_bound');
        el.data('togglewrap', true).find('.toggle_div').each(function () {
          $(this).data('togglewrap', {});
        });
        
        update();
        rememberSizes();
        
        el = null;
      });
    }
    
    function update() {
      $('.height_wrap', elements).each(function () {
        var el      = $(this);
        var toggler = el.find('span.toggle_img');
        
        if (!toggler.length) {
          toggler = $('<span class="toggle_img" />').appendTo(this);
        }
        
        var open  = el.hasClass('open');
        var val   = el.find('.val,.cell_detail');
        var empty = val.text() === '';
        
        if (open) {
          el.removeClass('open');
        }
        
        val[empty ? 'addClass' : 'removeClass']('empty');
        
        // check if content is hidden by overflow: hidden
        toggler[el.height() < val.height() ? 'show' : 'hide']();
        
        if (open) {
          el.addClass('open');
          
          if (empty) {
            toggler.trigger('click');
          }
        }
        
        el = val = toggler = null;
      });
    }
    
    function toggle(els) {
      rememberSize(els);       
      els.toggleClass('open').parents().first().toggleClass('open');
      els = null
    }
    
    function toggleblock(els) {
      return els.parents().filter(function () {
        return $(this).css('display') !== 'inline';
      }).first();
    }
    
    // dutyCycle: do as many as possible at same time but don't cause delays
    function dutyCycleStep(num, action, done, more) {
      var timeout = 1;
      
      if (more) {
        var start = $.now();
        var ret   = action(num);
        var end   = $.now();
        
        if (!ret) {
          if (done) {
            done();
          }
          
          return;
        }
        
        var actual = end - start;
        
        if (actual > 100) { num /= 2; }
        if (actual < 25)  { num *= 2; }
        
        timeout = Math.min(actual * 10, 2000);
      }
      
      setTimeout(function () { dutyCycleStep(num, action, done, 1); }, timeout);
    }
    
    function dutyCycle(action, done) {
      var start   = 0;
      var toggler = $('.toggle_div', elements);
      
      dutyCycleStep(1, function (times) {
        toggler.slice(start, start + times).each(action);
        start += times;
        return start < toggler.length && toggler.length;
      }, done);
    }
    
    function rememberSize(els) {
      if (!els.hasClass('toggle_img')) {
        els = $('.toggle_img', els);
      }
      
      var fix = els.parents('.toggleblock');
      
      if (!fix.length) {
        fix = toggleblock(els.parents('.toggle_div'));
      }
      
      fix.data('togglewrap.fixWidth', fix.width() - 16);
      
      els = fix = null;
    }
    
    function rememberSizes() {
      dutyCycle(function () {
        rememberSize($(this));
      }, function () {
        areSummariesSuperfluous();
      });
    }
    
    function areSummariesSuperfluous() {
      dutyCycle(function () {
        $(this).data('togglewrap.innerWidth', $('.cell_detail', this).width()).data('togglewrap.summaryWidth', $('.toggle_summary', this).width() + 100);
      }, function () {
        removeSuperfluousSummaries();
      });
    }
    
    function removeSuperfluousSummaries() {
      dutyCycle(function () {
        var toggler = $(this);
        var width   = toggleblock(toggler).data('togglewrap.fixWidth');
        
        if (toggler.data('togglewrap.innerWidth') < width) {
          toggler.replaceWith($('.cell_detail', toggler).removeClass('cell_detail'));
        } else if (width > toggler.data('togglewrap.summaryWidth')) {
          $('span.toggle-img', toggler).addClass('limpet');
        }
        
        toggler = null;
      });
    }
    
    if (arg === 'update') {
      update();
    } else {
      if(arg == 'redo') {
        elements.removeData('togglewrap');
      }
      var classes = '.heightwrap_inside, .cellwrap_inside';
      elements = elements.filter(classes).add(elements.find(classes));
      init();
    }
  }
  
  $.fn.togglewrap = function (arg) {
    return this.each(function () { $.togglewrap($(this), arg); });
  };
})(jQuery);
