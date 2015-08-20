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
  $.fn.new_table_core = function(config,data) {

    return {
      generate: function() {},
      go: function($table,$el) {},
      pipe: function() {
        return [
          // Example pipeline step
          function(orient) {
            console.log("forward");
            orient.hello = "world";
            return [orient,function(manifest,data) {
              console.log("back atcha",manifest.hello);
              delete manifest.world;
              return [manifest,data];
            }];
          }
        ];
      }
    };
  }; 

})(jQuery);
