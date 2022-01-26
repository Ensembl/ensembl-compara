/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

Ensembl.Panel.Piechart = Ensembl.Panel.Content.extend({  
  init: function () {
    var panel = this;
    
    this.base();
    
    if (typeof Raphael === 'undefined') {
      $.getScript('/raphael/raphael-min.js').done( function () {
        $.getScript('/raphael/g.raphael-min.js').done( function () {
          $.getScript('/raphael/g.pie-modified-min.js').done( function () { panel.getContent(); });
        });
      });
    }
  },
  
  getContent: function () {
    var panel   = this;
    var visible = [];
    
    this.graphData   = [];
    this.graphConfig = {};
    this.graphEls    = {};
    this.dimensions  = eval($('input.graph_dimensions', this.el).val());
    
    $('input.graph_data', this.el).each(function () {
      panel.graphData.push(eval(this.value));
    });
    
    $('input.graph_config', this.el).each(function () {
      panel.graphConfig[this.name] = eval(this.value);
    });
    
    for (i in this.graphData) {
      this.graphEls[i] = $('#graphHolder' + i);
      
      if (this.graphEls[i].is(':visible')) {
        visible.push(i);
      }
    }
    
    this.makeGraphs(visible);
  },
  
  makeGraphs: function (index) {
    var i, j, raphael, data, config, c;
    
    for (i in index) {
      if (this.graphEls[index[i]].data('done')) {
        continue;
      }
       
      config = { legend: [], colors: [] };
      data   = [];
      c      = 0;
      
      for (j in this.graphData[index[i]]) {
        if (typeof this.graphData[index[i]][j] === 'object') {
          data.push(this.graphData[index[i]][j][0]);
          config.legend.push(this.graphData[index[i]][j][1] + ': %%');
          
          if (this.graphColours) {
            config.colors.push(this.graphColours[this.graphData[index[i]][j][1]] || this.graphColours['default'][c++]);
            
            if (c === this.graphColours['default'].length) {
              c = 0;
            }
          }
        } else {
          data.push(this.graphData[index[i]][j]);
        }
      }

      raphael = Raphael('graphHolder' + index[i]);
      raphael.g.txtattr.font = "12px 'Luxi Sans','Helvetica', sans-serif";
 
      raphael.g.piechart(this.dimensions[0], this.dimensions[1], this.dimensions[2], data, $.extend(config, this.graphConfig));
      
      this.graphEls[index[i]].data('done', true);
    }
  }
});
