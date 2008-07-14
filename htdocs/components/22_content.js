/* Bits of JS used on static pages */

/** 
  "Jump to" on species list (home page)
**/

function dropdown_redirect( evt ) {
  var el = Event.findElement(evt,'select');
  var URL = el.options[el.options.selectedIndex].value;
  document.location = URL;
  return true;
}

function __init_dropdown_redirect( ) {
  $$('.dropdown_redirect').each(function(n){
    Event.observe(n,'change',dropdown_redirect);
  });
}
addLoadEvent( __init_dropdown_redirect );

/**
  Drag'n'drop selection of favourite species
**/

var performedSave = 0;

function toggle_reorder() {
  $('reorder_species').toggle();
  $('full_species').toggle();
}

function update_species(element) {
  //alert(element.id);
  if( !performedSave ) {
    performedSave = 1;
    var serialized_data = $A($('favourites_list').childNodes).map(function(n){return n.id.split('-')[1];}).join(',');
    new Ajax.Request( '/Account/SaveFavourites', {
      method    : 'get',
      parameters: { favourites: serialize_fave('favourites_list') },
      onSuccess: function(response){ $('full_species').innerHTML = response.responseText; performedSave = 0; },
      onFailure: function(response){ performedSave = 0; }
    });
  } 
}

function __init_species_reorder() {
  if ($('species_list')) {
    ['species_list','favourites_list'].each(function(v){
      Sortable.create( v,{
        'onUpdate'  : update_species,
        containment : ["species_list","favourites_list"],
        dropOnEmpty : false
      });
    });
  }
  $$('.toggle_link').each(function(n){
    Event.observe(n,'click',toggle_reorder);
  });
}

addLoadEvent( __init_species_reorder );
