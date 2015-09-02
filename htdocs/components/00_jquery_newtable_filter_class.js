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
  $.fn.newtable_filter_class = function(config,data) {
    return {
      filters: [{
        name: "class",
        display: function($menu,$el,values,state,kparams) {
          var v = {};
          var $out = $("<ul/>");
          values = values.slice();
          values.sort(function(a,b) { return a.localeCompare(b); });
          $.each(values,function(i,val) {
            var $li = $("<li/>").text(val).data('key',val).appendTo($out);
            $li.data('val',val);
            if(!state[val]) { $li.addClass("on"); }
            $li.on('click',function() {
              $(this).toggleClass('on');
              var key = $(this).data('key');
              if(state[val]) { delete state[val]; } else { state[val] = 1; }
              $el.trigger('update',state);
            });
          });
          if(values.length>2) { $out.addClass('use_cols'); }
          $menu.empty().append($out);
        },
        text: function(state,all) {
          var skipping = {};
          $.each(state,function(k,v) { skipping[k]=1; });
          var on = [];
          var off = [];
          $.each(all,function(i,v) {
            if(skipping[v]) { off.push(v); } else { on.push(v); }
          });
          var out = "None";
          if(on.length<=off.length) {
            out = on.join(', ');
          } else if(on.length) {
            out = 'All except '+off.join(', ');
          }
          if(out.length>20) {
            out = out.substr(0,20)+'...('+on.length+'/'+all.length+')';
          }
          return out;
        },
        visible: function(values) {
          return values && !!values.length;
        }
      }]
    };
  };
})(jQuery);
