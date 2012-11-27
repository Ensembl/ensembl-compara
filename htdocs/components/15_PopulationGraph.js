// $Revision$

Ensembl.Panel.PopulationGraph = Ensembl.Panel.Piechart.extend({
  init: function () {
    // Allele colours
    this.graphColours = {
      'A'       : '#00BB00',
      'T'       : '#FF0000',
      'G'       : '#FFD700',
      'C'       : '#0000FF',
      'default' : [ '#222222', '#FF00FF', '#008080', '#7B68EE' ] // Other colours if the allele is not A, T, G or C
    };
    
    this.base();
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
