// $Revision$

Ensembl.Panel.PopulationGraph = Ensembl.Panel.Content.extend({  
  init: function () {
    var panel = this;
    
    this.base();
    
    this.graphData = [];
    this.graphEls  = {};
    
    if (typeof Raphael === 'undefined') {
      $.getScript('/raphael/raphael-min.js', function () {
        $.getScript('/raphael/g.raphael-min.js', function () {
          $.getScript('/raphael/g.pie-modified-min.js', function () { panel.getContent(); });
        });
      });
    }
  },
  
  getContent: function () {
    var panel   = this;
    var visible = [];
    
    $('input.population', this.el).each(function () {
      panel.graphData.push(eval(this.value));
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
    var alleles  = [ 'A', 'T', 'G', 'C' ];
    var acolours = [ '#00BB00', '#FF0000', '#FFD700', '#0000FF' ];
    var bcolours = [ '#222222', '#FF00FF', '#008080', '#7B68EE' ]; // Other colours if the allele is not A, T, G or C
    var i, j, k, raphael, pieData, pieColors, piePercent, b, colourFlag;
    
    for (i in index) {
      if (this.graphEls[index[i]].data('done')) {
        continue;
      }
      
      pieData    = [];
      pieColors  = [];
      piePercent = [];
      raphael    = Raphael('graphHolder' + index[i]);
      raphael.g.txtattr.font = "12px 'Luxi Sans','Helvetica', sans-serif";
      b = 0;      
      
      // For each allele
      for (j in this.graphData[index[i]]) {
        pieData.push(this.graphData[index[i]][j][1]);
        piePercent.push(this.graphData[index[i]][j][0] + ': %%');
        colourFlag = 0;

        // Normal allele colour
        for (k in alleles) {
          if (this.graphData[index[i]][j][0] === alleles[k]) {
            pieColors.push(acolours[k]);
            colourFlag = 1;
          }
        }

        // Other colour
        if (colourFlag === 0 && b < bcolours.length) {
          pieColors.push(bcolours[b]);
          b++;
        }
      }
      
      raphael.g.piechart(25, 25, 20, pieData, { legend: piePercent, legendpos: "east", legendmark: 'arrow', colors: pieColors }); // Create the pie graph
      
      this.graphEls[index[i]].data('done', true);
    }
  },
  
  toggleContent: function (el) {
    if (el.hasClass('open') && !el.data('done')) {
      this.base(el);
      this.makeGraphs($('.pie_chart > div', '.' + el.attr('rel')).map(function () { return this.id.replace('graphHolder', ''); }).toArray());
      el.data('done', true);
    } else {
      this.base(el);
    }
    
    el = null;
  }
});
