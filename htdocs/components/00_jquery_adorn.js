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
  function sorted_each(hash,fn,map) {
    var arr = [];
    if(!map) { map = {}; }
    $.each(hash,function(k,v) { arr.push([k,v]); });
    arr.sort(function(a,b) {
      var al = a[0].toLowerCase();
      var bl = b[0].toLowerCase();
      if(map[a[0]]) { al = map[a[0]]; }
      if(map[b[0]]) { bl = map[b[0]]; }
      if(al<bl) { return -1; }
      if(al>bl) { return 1; }
      return 0;
    });
    $.each(arr,function(i,e) {
      fn(e[0],e[1]);
    });
  }

  function beat(def) {
    return def.then(function(data) {
      var d = $.Deferred();
      setTimeout(function() { d.resolve(data); },0);
      return d;
    });
  }

  function loop(def,fn,group,part) {
    return def.then(function(raw_input) {
      var input = [];
      $.each(raw_input,function(a,b) { input.push([a,b]); });
      d = $.Deferred().resolve(input);
      var output = [];
      for(var ii=0;ii<input.length;ii+=group) {
        (function(i) {
          d = beat(d.then(function(j) {
            for(j=0;j<group && i+j<input.length;j++) {
              var c = fn(input[i+j][0],input[i+j][1]);
              if(c !== undefined) {
                output.push(c);
              }
            }
            return $.Deferred().resolve(output);
          }));
        })(ii);
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

  function fix_letters(text,ref,seq) {
    var out = "";

    var s = undefined;
    if(!seq.letter) { seq.letter = []; }
    for(var i=0;i<text.length;i++) {
      if(i < seq.letter.length) { s = seq.letter[i]; }
      if(s) {
        out += ref.letter[s];
      } else {
        out += text.substr(i,1);
      }
    }
    return out;
  }

  function unprefix(ref) {
    var len = 0;
    for(var i=0;i<ref.length;i++) {
      len += ref[i][0];
      if(len) {
        ref[i][0] = ref[i-1].substr(0,len);
      } else {
        ref[i][0] = "";
      }
      ref[i] = ref[i][0] + ref[i][1];
    }
    return ref;
  }

  function unrle(seq) {
    var prev = undefined;
    var out = [];

    if(!$.isArray(seq)) { return seq; }
    for(var i=0;i<seq.length;i++) {
      if(seq[i]<0) {
        for(var j=0;j<-seq[i];j++) { out.push(prev); }
      } else {
        out.push(seq[i]);
        prev = seq[i];
      }
    }
    return out;
  }

  function make_groups(seq,textlen) {
    var styles = [];
    $.each(seq,function(key,values) {
      var value = undefined;
      for(var i=0;i<textlen;i++) {
        if(i < values.length) { value = values[i]; }
        if(!styles[i]) { styles[i] = {}; }
        styles[i][key] = value;
      }
    });
    var last = null;
    $.each(styles,function(i,cur) {
      if(last) {
        var diffs = 0;
        $.each(seq,function(k,v) {
          if(k == 'letter') { return; }
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
      otag = "a class='sequence_info' draggable='false'";
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

  function prepare_adorn_span(text,ref,seq) {
    text = fix_letters(text,ref,seq);
    var groups = make_groups(seq,text.length);
    var pos = 0;
    var out = '';
    $.each(groups,function(i,group) {
      out += adorn_group(ref,group,text.substr(pos,group.__len));
      pos += group.__len;
    });
    return out;
  }

  function set_status($outer,state) {
    var $initial = $outer.closest('.initial_panel');
    var $loading = $outer.parents('.js_panel').find('.ad-markup-loading');
    var $loaded = $outer.parents('.js_panel').find('.ad-markup-loaded');
    var num = $initial.data('number');
    if(!num) { num=0; }
    num += state;
    $initial.data('number',num);
    if(num) { $loaded.hide(); $loading.show(); }
    else    { $loaded.show(); $loading.hide(); }
  }

  function add_legend($outer,legend,loading) {
    var $key = $outer.parents('.js_panel').find('._adornment_key');
    // Add new legend to data
    var data = $key.data('data');
    if(!data) { data = {}; }
    if(legend) {
      $.each(legend,function(cn,cv) {
        if(!data[cn] || data[cn] === -1) { data[cn] = {}; }
        if(cn == '_messages') {
          $.each(cv,function(i,ev) {
            data[cn][ev] = 1;
          });
        } else {
          $.each(cv,function(en,ev) {
            data[cn][en] = ev;
          });
        }
      });
    }
    delete data['Basic Annotation'];
    var any = 0;
    $.each(data,function(a,b) { any = 1; });
    if(!any) {  
      data['Basic Annotation'] = -1;
    }
    // Remove old "loading" data
    $.each(data,function(dn,dv) {
      if(dv==-1) { delete data[dn]; }
    });
    // Add new "loading" data
    $.each(loading,function(i,load) {
      if(!data[load]) { data[load] = -1; }
    });
    $key.data('data',data);
    // Replace legend with new data
    var key = '';
    sorted_each(data,function(cn,cv) {
      if(cn == '_messages') { return; }
      var row = '';
      if(cv === -1) {
        row += '<li><span class="ad-loading">loading</span></li>';
      } else {
        sorted_each(cv,function(en,ev) {
          row += '<li><span class="adorn-key-entry" style="';
          row += ev['default'] ? 'background-color:' + ev['default'] + ';' : '';
          row += ev.label ? 'color:' + ev.label + ';' : '';
          row += ev.extra_css ? ev.extra_css : '';
          row += '">';
          if (ev.title) {
            row += '<span title="' + ev.title + '"';
            row += ev.label ? ' style="border-color:' + ev.label + '"' : '';
            row += '>' + ev.text + '</span>';
          } else {
            row += ev.text;
          }
          row += '</span></li>';
        });
      }
      if(row) {
        var name = cn.substr(0,1).toUpperCase()+cn.substr(1);
        name = name.replace(/([\/-])/g,"$1 ");
        key += '<dt>'+name+'</dt><dd><ul>'+row+'</ul></dd>';
      }
    },{ other: "~" });
    var messages = '';
    if(data._messages) {
      $.each(data._messages,function(message,v) {
        messages += '<li>'+message+'</li>';
      });
    }
    var html = '';
    key += '<dt>Markup</dt><dd><ul><li><span class="ad-markup-loading ad-loading">loading</span><span class="ad-markup-loaded" style="display: none">loaded</span></li></ul></dd>';
    var $key = $outer.parents('.js_panel').find('._adornment_key');
    if(key) { html += '<dl>' + key +'</dl>'; }
    if(messages) { html += '<ul class="alignment-key">' + messages + '</ul>'; }
    $key.html(html).toggle(!!html).find('span[title]').helptip();
    set_status($outer,0);
  }

  function _do_adorn(outer,fixups,data) {
    var $outer = $(outer);
    if(($outer.hasClass('adornment-running') && !data) ||
       $outer.hasClass('adornment-done')) {
      return $.Deferred().resolve(0);
    }
    var wrapper = $outer.wrap("<div></div>").parent();
    $outer.addClass('adornment-running');
    if(!data) {
      data = $.parseJSON($('.adornment-data',outer).text());
    }
    add_legend($outer,null,data.expect||data.provisional.expect);
    var d;
    if(data.url) {
      d = $.Deferred().resolve(data.provisional);
    } else {
      d = $.Deferred().resolve(data);
    }
    d = d.then(function(data) {
      $.each(data.ref,function(k,v) {
        data.ref[k] = unprefix(data.ref[k]);
      });
      $.each(data.seq,function(k,v) {
        if($.isPlainObject(data.seq[k])) {
          $.each(data.seq[k],function(a,b) {
            data.seq[k][a] = unrle(data.seq[k][a]);
          });
        }
      });
      data.seq = unrle(data.seq);
      return loop($.Deferred().resolve(data.seq),function(key,values) {
        if(values) {
          var el = $('.adorn-'+key,outer);
          if(el.length) {
            var fl = {};
            $.each(data.flourishes,function(k,v) {
              var f = v[key];
              var fl_el = $('.ad-'+k+'-'+key,outer);
              if(f && fl_el.length) {
                fl[k] = [fl_el,$.parseJSON(f).v];
              }
            });
            return [el,el.text(),data.ref,values,fl];
          } else {
            return undefined;
          }
        }
      },1000,'a');
    });
    d = loop(d,function(i,task) {
      var out = prepare_adorn_span(task[1],task[2],task[3]);
      return [task[0],out,task[4]];
    },1000,'b');
    d = loop(d,function(i,change) {
      change[0].html(change[1]);
      $.each(change[2],function(i,fl) {
        fl[0].html(fl[1]);
      });
    },1000,'c');
    d = fire(d,function() {
      $('.adornment-data',outer).remove();
      $outer.appendTo(wrapper);
      add_legend($outer,data.legend||data.provisional.legend,
                        data.expect||data.provisional.expect);
    });
    if(data.url) {
      d = d.then(function() {
        // Look for parent adornment-load for lock
        var load_div = $outer.parents('.adornment-load');
        if(!load_div.length || !load_div.hasClass('adornment-loaded')) {
          load_div.addClass('adornment-loaded')
          // Do load
          $.paced_ajax({ dataType: "html", url: data.url}).then(function(page) {
            var start = $outer;
            if(load_div.length) { start = load_div.get(0); }
            var adornments = $('.adornment',start).addBack('.adornment');
            var datas = $('.adornment-data',page);
            for(var i=0;i<adornments.length;i++) {
              _do_adorn(adornments[i],fixups,$.parseJSON($(datas[i]).text()));
            }
            set_status($outer,-1);
          });
          set_status($outer,1);
        }
      });
    } else {
      d = fire(d,function() {
        $outer.addClass('adornment-done');
        $outer.removeClass('adornment-running');
        $outer.closest('.initial_panel').find('.markup-loading').html("Finished");
      });
    }
    d = d.then(function() { fixups(outer); });
    return d;
  }

  $.fn.adorn = function(fixups) {
    var all = [];
    this.each(function(i,outer) {
      beat(_do_adorn(outer,fixups));
    });
    return d;
  }; 

})(jQuery);
