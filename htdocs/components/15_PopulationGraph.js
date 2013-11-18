// $Revision$

Ensembl.Panel.PopulationGraph = Ensembl.Panel.Piechart.extend({
  init: function () {
    // Allele colours
    this.graphColours = {
      'A'       : '#00A000',
      'T'       : '#FF0000',
      'G'       : '#FFCC00',
      'C'       : '#0000FF',
      '-'       : '#000000',
      'default' : [ '#008080', '#FF00FF', '#7B68EE' ] // Other colours if the allele is not A, T, G, C or -
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
