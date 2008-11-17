/** 
  The following file contains a number of small blocks of 
  javascript code from the static content pages in Ensembl
**/

/** 
  The following code adds code which, on changing a drop-down
  box's value, goes to the URL specified by the value of the
  dropdown element.
**/

function dropdown_redirect( evt ) {
/** Function that actually does the redirect **/
  var el = Event.findElement(evt,'select');
  var URL = el.options[el.options.selectedIndex].value;
  document.location = URL;
  return true;
}

/**
  Add lambda function which adds an observer to each
  of the nodes which have a value dropdown_redirect
**/
addLoadEvent( function(){ 
  $$('.dropdown_redirect').each(function(n){
    Event.observe(n,'change',dropdown_redirect);
  });
});

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
      parameters: { favourites: serialized_data },
      onSuccess: function(response){ 
        $('full_species').innerHTML = response.responseText; performedSave = 0;
        $$('.toggle_link').each(function(n){
          if( ENSEMBL_AJAX == 'enabled' ) {
            Event.observe(n,'click',toggle_reorder);
          } else {
            n.hide();
          }
        });
      }, 
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
    if( ENSEMBL_AJAX == 'enabled' ) {
      Event.observe(n,'click',toggle_reorder);
    } else {
      n.hide();
    }
  });
}

addLoadEvent( __init_species_reorder );


/** 
  The following code adds code which, on changing a radio
  button's value, goes to the URL specified by the form action
**/

function autosubmit( evt ) {
/** Function that actually does the form submission **/
  var el = Event.findElement(evt,'form');
  var t  = el.up('div#modal_panel');
  if( t ) {
    new Ajax.Request( el.action, {
      method: el.method,
      parameters: el.serialize(true),
      onSuccess: function( transport ) {
        modal_success(transport)
      },
      onFailure: function( transport ) {
        $('modal_content').innerHTML = '<p class="ajax_error">Failure: the resource failed to load</p>';
      }
    });
  } else {
    el.submit();
  }
  return true;
}

/**
  Add lambda function which adds an observer to each
  of the nodes which have a value radio_autosubmit
**/
addLoadEvent( function(){ 
  $$('.autosubmit').each(function(n){
    Event.observe(n,'change',autosubmit);
  });
});

