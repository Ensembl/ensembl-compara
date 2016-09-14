/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016] EMBL-European Bioinformatics Institute
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
  // TODO: should be moved back into tabular
  function new_th(key,cc) {
    var text = cc.label || cc.title || key;
    var attrs = {};
    var classes = [];
    attrs['data-key'] = key || '';
    if(cc.sort)  { classes.push('sorting'); }
    if(cc.help) {
      var help = $('<span class="ht _ht"/>').attr('title',cc.help).html(text);
      text = $('<div/>').append(help).html();
    }
    var attr_str = "";
    $.each(attrs,function(k,v) {
      attr_str += ' '+k+'="'+v+'"';
    });
    if(classes.length) {
      attr_str += ' class="'+classes.join(' ')+'"';
    }
    return "<th "+attr_str+">"+text+"</th>";
  }

  $.fn.new_table_config = function(config,data) {
    return {
      columns: function(config,columns) {
        $.each(config.columns,function(i,key) {
          var cc = config.colconf[key];
          // TODO to plugin
          if(cc.type && cc.type.screen && cc.type.screen.unshowable) {
            return;
          }
          columns.push(new_th(key,cc));
        });
      }
    };
  }; 
})(jQuery);
