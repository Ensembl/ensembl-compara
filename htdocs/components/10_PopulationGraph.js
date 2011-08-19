// $Revision$

Ensembl.Panel.PopulationGraph = Ensembl.Panel.extend({  
  init: function () {
    var panel = this;
    
    this.base();
    
    if (typeof Raphael === 'undefined') {
      $.getScript('/raphael/raphael-min.js', function () {
        $.getScript('/raphael/g.raphael-min.js', function () {
          $.getScript('/raphael/g.pie-modified-min.js', function () { panel.getContent(); });
        });
      });
    }
  },
  
  getContent: function () {
    var alleles   = [ 'A', 'T', 'G', 'C' ];
    var acolours  = [ '#00BB00', '#FF0000', '#FFD700', '#0000FF' ];
    var bcolours  = [ '#FF00FF', '#000000', '#008080', '#7B68EE' ]; // Other colours if the allele is not A, T, G or C
    var graphData = [];
    var i, j, k, raphael, pieData, pieColors, piePercent, b, colourFlag;
    
    $('input.population', this.el).each(function () {
      graphData.push(eval(this.value));
    }); 
    
    // For each graph
    for (i in graphData) {
      pieData    = [];
      pieColors  = [];
      piePercent = [];
      raphael    = Raphael('graphHolder' + i);
      raphael.g.txtattr.font = "12px 'Luxi Sans','Helvetica', sans-serif";
            
      // For each allele
      for (j in graphData[i]) {
        pieData.push(graphData[i][j][1]);
        piePercent.push(graphData[i][j][0] + ': %%');
        colourFlag = 0;

        // Normal allele colour
        for (k in alleles) {
          if (graphData[i][j][0] === alleles[k]) {
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
    }
  }
});
