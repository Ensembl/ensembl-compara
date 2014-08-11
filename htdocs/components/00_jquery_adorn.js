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
  function beat(def) {
    return def.then(function(data) {
      var d = $.Deferred();
      setInterval(function() { d.resolve(data); },0);
      return d;
    });
  }

  function loop(def,fn,group,part) {
    return def.then(function(raw_input) {
      var input = [];
      $.each(raw_input,function(a,b) { input.push([a,b]); });
      d = $.Deferred().resolve(input);
      var output = [];
      for(var i=0;i<input.length;i+=group) {
        d = beat(d.then(function(j) {
          for(j=0;j<group && i+j<input.length;j++) {
            var c = fn(input[i+j][0],input[i+j][1]);
            if(c !== undefined) {
              output.push(c);
            }
          }
          return $.Deferred().resolve(output);
        }));
      }
      return d;
    });
  }

  function fire(def,fn) {
    return def.then(function(data) {
      fn();
      return $.Deferred().resolve(data);
    });
  }

  function make_groups(seq) {
    var styles = [];
    $.each(seq,function(key,values) {
      $.each(values,function(i,value) {
        if(!styles[i]) { styles[i] = {}; }
        styles[i][key] = value;
      });
    });
    var last = null;
    $.each(styles,function(i,cur) {
      if(last) {
        var diffs = 0;
        $.each(seq,function(k,v) {
          if(last[k] || cur[k]) {
            if(!last[k] || !cur[k] || last[k]!=cur[k]) { diffs = 1; }
          }
        });
        if(!diffs) { cur.__repeat = 1; }
      }
      last = cur;
    });
    var groups = [];
    $.each(styles,function(i,cur) {
      if(cur.__repeat) {
        groups[groups.length-1].__len++;
      } else {
        cur.__len = 1;
        groups.push(cur);
      }
    });
    return groups;
  }

  function adorn_group(ref,group,text) {
    var otag = "span";
    var ctag = "span";
    if(group.href) {
      otag = "a class='sequence_info'";
      ctag = "a";
    }
    if(group.tag) {
      otag = ref.tag[group.tag];
      ctag = ref.tag[group.tag];
    }
    $.each(['href','title','style'],function(i,k) {
      if(group[k]) {
        otag += ' '+k+'="'+ref[k][group[k]]+'"';
      }
    });
    return "<"+otag+">"+text+"</"+ctag+">";
  }

  function prepare_adorn_span(text,ref,seq,xxx) {
    var groups = make_groups(seq);
    var pos = 0;
    var out = '';
    $.each(groups,function(i,group) {
      out += adorn_group(ref,group,text.substr(pos,group.__len));
      pos += group.__len;
    });
    return out;
  }

  function _do_adorn(outer) {
    var $outer = $(outer);
    if(!$outer.hasClass('adornment-done')) {
      $outer.addClass('adornment-done');
      var data = $.parseJSON($('.adornment-data',outer).text());
      if ($.isEmptyObject(data.ref)) {
        return;
      }
      var wrapper = $outer.wrap("<div></div>").parent();
      var d = $.Deferred().resolve(data.seq);
      d = loop(d,function(key,values) {
        var el = $('.adorn-'+key,outer);
        if(el.length) {
          return [el,el.text(),data.ref,values,key];
        } else {
          return undefined;
        }
      },1000,'a');
      d = loop(d,function(i,task) {
        var out = prepare_adorn_span(task[1],task[2],task[3],task[4]);
        return [task[0],out];
      },1000,'b');
      d = fire(d,function() {
        $outer.detach();
      });
      d = loop(d,function(i,change) {
        change[0].html(change[1]);
      },1000,'c');
      d = fire(d,function() {
        $('.adornment-data',outer).remove();
        $outer.appendTo(wrapper);
      });
    }
  }

  $.fn.adorn = function() {
    this.each(function(i,outer) {
      setTimeout(function() { _do_adorn(outer); },50);
    });
    return this;
  }; 

})(jQuery);
