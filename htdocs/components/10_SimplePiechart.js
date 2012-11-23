// $Revision$

Ensembl.Panel.SimplePiechart = Ensembl.Panel.Content.extend({  
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
    
    $('input.piechart', this.el).each(function () {
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
    var i, j, k, raphael, pieData, piePercent, pieColors;
    
    for (i in index) {
      if (this.graphEls[index[i]].data('done')) {
        continue;
      }
       
      pieData    = [];
      piePercent = [];
      pieColors  = ['#1751A7', '#FFFFFF']
      pieData.push(this.graphData[index[i]][0][0]);
      pieData.push(this.graphData[index[i]][0][1]);
      piePercent.push('coverage: %%');
      piePercent.push('no coverage: %%');

      raphael    = Raphael('graphHolder' + index[i]);
      raphael.g.txtattr.font = "12px 'Luxi Sans','Helvetica', sans-serif";
 
      raphael.g.piechart(80, 80, 75, pieData, { colors: pieColors, stroke: "#999" }); 
      
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
