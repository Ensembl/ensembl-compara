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
    this.imagePath = '/i/species/48/';
  },
  
  updateTaxonSelection: function(items) {
  	var panel = this;
  	var key;
  	// empty and re-populate the species list
  	panel.elLk.list.empty();
    panel.elLk.checkboxes.empty();
  	$.each(items, function(index, item){
  		key = item.key.charAt(0).toUpperCase() + item.key.substr(1); // ucfirst
      var _delete = $('<span/>', {
        text: 'x',
        'class': 'ss-selection-delete',
        click: function() {
          // Update taxon selection
          var clicked_item_title = $(this).parent('li').find('span.ss-selected').html();
          var updated_items = [];
          $.each(items, function(i, item) {
            if(clicked_item_title !== item.title) {
              updated_items.push(item);
            }
          });
          Ensembl.EventManager.trigger('updateTaxonSelection', updated_items);
          // Remove item from the Blast form list
          $(this).parent('li').remove();
        }
      });

      item.img_url = panel.imagePath + item.key + '.png';

      var _selected_img = $('<img/>', {
        src: item.img_url
      });

      var _selected_item = $('<span/>', {
        text: item.title,
        'data-title': item.title,
        'data-key': item.key,
        'class': 'ss-selected',
        title: item.title
      });
      
      var li = $('<li/>', {
      }).append(_selected_img, _selected_item, _delete).appendTo(panel.elLk.list);
      $(panel.elLk.checkboxes).append('<input type="checkbox" name="species" value="' + key + '" checked>' + item.title + '<br />'); 
  	}); 
  	
  	// update the modal link href in the form
  	var modalBaseUrl = panel.elLk.modalLink.attr('href').split('?')[0];
  	var keys = $.map(items, function(item){ return item.key; });
  	var queryString = $.param({s: keys, multiselect: 1}, true);
  	panel.elLk.modalLink.attr('href', modalBaseUrl + '?' + queryString);
  }
});
