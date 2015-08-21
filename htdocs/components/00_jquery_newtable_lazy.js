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

(function($) {
  var elements = [];
  var coords = [];

  var wiggle = 1000;

  function debounce(fn,msec) {
    var id;
    return function () {
      var that = this;
      var args = arguments;
      if(!id) {
        id = setTimeout(function() {
          id = null;
          fn.apply(that,args);
        },msec);
      }
    }
  }

  function refresh_element(i,el) {
    var etop = el.offset().top;
    var ebot = etop + +el.outerHeight(true);
    coords[i] = [etop-wiggle,ebot+wiggle];
  }

  function refresh() {
    for(var i=0;i<elements.length;i++) {
      refresh_element(i,elements[i]);
    }
  }

  function awaken(el) {
    el.trigger('awaken');
    el.addClass('__awake');
    refresh();
  }

  function check() {
    var wtop = $(window).scrollTop();
    var wbot = wtop + $(window).height();

    while(true) {
      for(var i=0;i<elements.length;i++) {
        if(elements[i].hasClass('__awake')) { continue; }
        if(wbot>coords[i][0] && wtop<coords[i][1]) {
          awaken(elements[i]);
          break; // from the top
        }
      }
      break; // all done
    }
  }

  function eager() {
    var wtop = $(window).scrollTop();
    var wbot = wtop + $(window).height();
    var nearby = 0;
    var target = null;
    for(var i=0;i<elements.length;i++) {
      if(wbot>coords[i][0] && wtop<coords[i][1]) { nearby = 1; }
      if(elements[i].hasClass('__awake')) { continue; }
      if(nearby) { target = elements[i]; break; }
      if(!target) { target = elements[i]; }
    }
    if(target) { awaken(target); }
  }

  var check_soon = debounce(check,500);
  $(window).scroll(function() { check_soon(); });

  $.fn.lazy = function(arg) {
    this.each(function(i,el) {
      var $this = $(this);
      if(!$this.hasClass('__lazy')) {
        elements.push($this);
        refresh_element(elements.length-1,$this);
        $this.addClass('__lazy');
      } else {
        $this.removeClass('__awake');
      }
    }); 
  };

  var refresh_soon = debounce(refresh,500);
  $.lazy = function(arg,val) {
    if(arg == 'refresh') {
      refresh_soon();
    } else if(arg == 'periodic') {
      setInterval(function() { refresh_soon(); check_soon(); },5000);
    } else if(arg == 'eager') {
      console.log('eager');
      eager();
    }
  }

})(jQuery);
