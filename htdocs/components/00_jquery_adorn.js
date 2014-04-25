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
        $outer.addClass('adormnent-done');
        $('.adornment-data',outer).remove();
        $outer.appendTo(wrapper);
      }
    });
    return this;
  }; 

})(jQuery);
