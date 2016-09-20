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
  $.fn.newtable_decorate_recolour = function(config,data) {
    function decorate_fn(column,extras,series) {
      var recolour;
      if(extras['*'] && extras['*'].recolour) {
        recolour = extras['*'].recolour;
      }

      return function(html,row) {
        if(!recolour) { return html; }
        // TODO avoid stomping with repeated substitutions. These cannot
        // occur in current uses, but could if used more broadly, esp.
        // bad as depends on evaluation order of unordered hash. But
        // how to make quick? eg.
        // { cat -> dog, loft -> attic } => cloft -> dogtic/cattic
        $.each(recolour,function(k,v) {
          html = html.replace(new RegExp(k,"g"),
                              '<span style="color:'+v+'">'+k+'</span>');
        });
        return html;
      };
    }

    var decorators = {};
    $.each(config.colconf,function(key,cc) {
      if(cc.decorate && $.inArray("recolour",cc.decorate)!=-1) {
        decorators[key] = [decorate_fn];
      }
    });

    return {
      decorators: {
        recolour: decorators
      }
    };
  }; 

})(jQuery);
