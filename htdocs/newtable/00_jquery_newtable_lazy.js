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

(function($) {
  var elements = [];
  var coords = [];

  var wiggle = 1000;
  var miles_away = 50000;

  function still_alive(el) {
    var p = el.parents();
    if(!p.length) { return false; }
    if($(p[p.length-1]).prop("tagName") != "HTML") { return false; }
    return true;
  }

  function refresh_element(i,el) {
    var etop = el.offset().top;
    var ebot = etop +el.outerHeight(true);
    coords[i] = [etop-wiggle,ebot+wiggle];
  }

  function refresh() {
    for(var i=0;i<elements.length;i++) {
      refresh_element(i,elements[i]);
      if(!still_alive(elements[i])) {
        elements.splice(i,1);
        coords.splice(i,1);
        i--;
      }
    }
  }

  function awaken(el) {
    el.trigger('awaken');
    el.addClass('__awake');
    refresh();
  }

  function sleepen(el) {
    el.trigger('sleepen');
    el.removeClass('__awake');
    refresh();
  }

  function check() {
    var wtop = $(window).scrollTop();
    var wbot = wtop + $(window).height();
    var height = $(document).height();
    var i;
    // Awaken some elements?
    while(true) {
      for(i=0;i<elements.length;i++) {
        if(elements[i].hasClass('__awake')) { continue; }
        if(wbot>coords[i][0] && wtop<coords[i][1]) {
          awaken(elements[i]);
          break; // from the top
        }
      }
      break; // all done
    }
    // Send some to sleep?
    for(i=0;i<elements.length;i++) {
      if(coords[i][0] < miles_away/2 ||
         coords[i][1] > height - miles_away/2) {
        elements[i].removeClass('__miles_away');
      } else if(coords[i][0]-wtop > miles_away ||
                wbot-coords[i][1] > miles_away) {
        if(!elements[i].hasClass('__miles_away')) {
          elements[i].addClass('__miles_away');
          if(elements[i].hasClass('__awake')) {
            sleepen(elements[i]);
          }
        }
      } else {
        elements[i].removeClass('__miles_away');
      }
    }
  }

  function eager() {
    var i;
    refresh();
    check();
    var wtop = $(window).scrollTop();
    var wbot = wtop + $(window).height();
    var height = $(document).height();
    var targets = [null,null,null,null];
    for(i=0;i<elements.length;i++) {
      var prio = 3;
      if(coords[i][1] > height - miles_away/2) { prio = 2; }
      if(coords[i][0] < miles_away && !targets[1]) { prio = 1; }
      if(wbot>coords[i][0] && wtop<coords[i][1]) { prio = 0; }
      if(elements[i].hasClass('__awake')) { continue; }
      if(elements[i].hasClass('__miles_away')) { continue; }
      targets[prio] = elements[i];
    }
    for(i=0;i<targets.length;i++) {
      if(targets[i]) { awaken(targets[i]); break; }
    }
  }

  var check_soon = $.debounce(check,500);
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

  var refresh_soon = $.debounce(refresh,500);
  $.lazy = function(arg,val) {
    if(arg == 'refresh') {
      refresh_soon();
    } else if(arg == 'periodic') {
      setInterval(function() { refresh_soon(); check_soon(); },5000);
    } else if(arg == 'eager') {
      eager();
    }
  };

})(jQuery);
