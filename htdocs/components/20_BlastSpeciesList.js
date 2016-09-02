Ensembl.Panel.BlastSpeciesList = Ensembl.Panel.extend({
  constructor: function (id, params) {
    var panel = this;
    panel.base(id);
    Ensembl.EventManager.register('updateTaxonSelection', panel, panel.updateTaxonSelection);
  },
  
  init: function () {  
 		this.base();
 		this.elLk.checkboxes = $('.checkboxes', this.el);
 		this.elLk.list 		   = $('.list', this.el);
 		this.elLk.modalLink  = $('.modal_link', this.el);
  },
  
  updateTaxonSelection: function(items) {
  	var panel = this;
  	var key;
  	
  	// empty and re-populate the species list
  	panel.elLk.list.empty();
    panel.elLk.checkboxes.empty();
  	$.each(items, function(index, item){
  		key = item.key.charAt(0).toUpperCase() + item.key.substr(1); // ucfirst
  		$(panel.elLk.list).append(item.title + '<br />');
      $(panel.elLk.checkboxes).append('<input type="checkbox" name="species" value="' + key + '" checked>' + item.title + '<br />'); 
  	}); 
  	
  	// update the modal link href in the form
  	var modalBaseUrl = panel.elLk.modalLink.attr('href').split('?')[0];
  	var keys = $.map(items, function(item){ return item.key; });
  	var queryString = $.param({s: keys}, true);
  	panel.elLk.modalLink.attr('href', modalBaseUrl + '?' + queryString);
  }
});
