/* Bits of JS used on static pages */

/* "Jump to" on species list (home page) */

function dropdown_redirect( id ) {
  var element = document.getElementById(id);
  var URL = element.options[element.options.selectedIndex].value;
  document.location = URL;
  return true;
}

/* Drag'n'drop selection of favourite species */

var performedSave = 0;

function toggle_reorder() {
  if (document.getElementById('reorder_species').style.display == 'none') {
    document.getElementById('reorder_species').style.display = 'block';
    document.getElementById('full_species').style.display = 'none';
  } else {
    document.getElementById('full_species').style.display = 'block';
    document.getElementById('reorder_species').style.display = 'none';
  }
}

function update_species(element) {
  //alert(element.id);
  if (!performedSave) {
    performedSave = 1;
    var url = "/Account/SaveFavourites";
    var data = "favourites=" + serialize_fave('favourites_list');
    var prepare = new Ajax.Request(url,
                         { method: 'get', parameters: data, onComplete: saved });
  } 
}

function saved(response) {
  document.getElementById('full_species').innerHTML = response.responseText;
  performedSave = 0;
}

function serialize_fave(element) {
  // Based on Sortable.serialize from Scriptaculous
  var items = $(element).childNodes;
  var queryComponents = new Array();
  for(var i=0; i<items.length; i++) {
    queryComponents.push(items[i].id.split("-")[1]);
  }
  return queryComponents.join(",");
}

Sortable.create('species_list', {"onUpdate":update_species, containment:["species_list","favourites_list"], dropOnEmpty:false});
Sortable.create('favourites_list', {"onUpdate":update_species, containment:["species_list","favourites_list"], dropOnEmpty:false});
