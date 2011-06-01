// $Revision$

Ensembl.Panel.PopulationGraph = Ensembl.Panel.extend({  
  init: function () {
    var panel = this;
    
    this.base();
    
    if (typeof Raphael === 'undefined') {
      Ensembl.loadScript('/raphael/raphael-min.js', function () {
        Ensembl.loadScript('/raphael/g.raphael-min.js', function () {
          Ensembl.loadScript('/raphael/g.pie-modified.js', 'getContent', panel);
        });
      });
    }
  },

  getContent: function () {
    var graphData = [];
    var i, j, r, pie, pieData, pieLegend;
 
    $('input.population', this.el).each(function () {
      graphData.push(eval(this.value));
    });
    
		var alleles = ['A','T','G','C'];
		var acolours = ['#00FF00','#FF0000','#FFD700','#0000FF'];
		var bcolours = ['#FF00FF','#000000','#008080','#7B68EE']; // Other colours if the allele is not A, T, G or C
		
		// For each graph //
    for (i in graphData) {
      r = Raphael('graphHolder' + i);

      r.g.txtattr.font = "12px 'Luxi Sans','Helvetica', sans-serif";
      
      pieData    = [];
      pieLegend  = [];
			pieColors  = [];
			piePercent = [];
      
			var legend_flag = 0;
			var data_flag   = 0;
			var b_id = 0;
			
			// For each allele //
      for (j in graphData[i]) {

        pieData.push(graphData[i][j][1]);
				piePercent.push(graphData[i][j][0]+': %%');
				
				var cflag = 0;
				// Normal allele colour
				for (k in alleles) {
					if (graphData[i][j][0] == alleles[k]) {
						pieColors.push(acolours[k]);
						cflag = 1;
					}
				}
				// Other colour
				if (cflag == 0 && b_id < bcolours.length) {
					pieColors.push(bcolours[b_id]);
					b_id ++;
				}
      }
			// Create the pie graph
			pie = r.g.piechart(25, 25, 20, pieData, {legend: piePercent, legendpos: "east", legendmark: 'arrow', colors: pieColors});
		}
  }
});
