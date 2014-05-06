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

  function adorn_span(el,ref,seq,xxx) {
    var groups = make_groups(seq);
    var text = el.text();
    var pos = 0;
    var out = '';
    $.each(groups,function(i,group) {
      out += adorn_group(ref,group,text.substr(pos,group.__len));
      pos += group.__len;
    });
    el.html(out);
  }

  $.fn.adorn = function() {
    this.each(function(i,outer) {
      var $outer = $(outer);
      if(!$outer.hasClass('adornment-done')) {
        var wrapper = $outer.wrap("<div></div>").parent();
        $outer.detach(); 
        var data = $.parseJSON($('.adornment-data',outer).text());
        $.each(data.seq,function(key,values) {
          var el = $('.adorn-'+key,outer);
          if(el.length) {
            adorn_span(el,data.ref,values,key);
          }
        });
        $outer.addClass('adornment-done');
        $('.adornment-data',outer).remove();
        $outer.appendTo(wrapper);
      }
    });
    return this;
  }; 

})(jQuery);
