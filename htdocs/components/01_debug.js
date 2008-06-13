/***********************************************************************
  Debugging code - this code displays the debug box at the top of the
  webpage 
  
  Note code is only run once - not on subsequent Ajax requests..
***********************************************************************/

/** 
  function _debug_press( event )
  
  Clicking on one of the buttons in the debug box; toggles the
  messages of the particular type; except for the clear button which
  removes all the messages...

**/

function _debug_press(evt) {
  bu    = Event.element(evt);
  bu_id = bu.id;
  if( bu_id == 'debug_clear' ) {
// "the clear" button is different from the rest! - it clears the list
    $('debug_list').innerHTML = '';
  } else {
    if( bu.hasClassName(  'debug_button' ) ){
      bu.addClassName(    'debug_button_inv' );
      bu.removeClassName( 'debug_button'     );
      $$( '.'+bu_id ).each(function(n){n.hide()});
    } else {
      bu.addClassName(    'debug_button'     );
      bu.removeClassName( 'debug_button_inv' );
      $$( '.'+bu_id ).each(function(n){n.show()});
    }
  }
}


/** 
  function __debug( message, level ); 
  
  push a debug message onto the tree with the appropriate level;
  default for level is "info"
  
  Note... only works if there is a "debug" node in the DOM
  
  There are four wrapper functions with pre-specify the level...
  
  __info(    message );
  __warning( message );
  __error(   message );
  __success( message );
**/


function __debug( s,l ) {
  if($('debug')) {
  if(!l) l = 'info'
    var cl = "debug_"+l;
    var X = Builder.node('li',{className:cl}, "["+l+"] "+s);
    $('debug_list').appendChild(X);
    if( $(cl).hasClassName('debug_button_inv') ) {
      X.hide();
    }
  }
}

function __info(s)    { __debug(s,'info');    }
function __warning(s) { __debug(s,'warning'); }
function __error(s)   { __debug(s,'error');   }
function __success(s) { __debug(s,'success'); }

/**
  debug initialisation function - 
  if a div with id "debug" exists - create debug window;
  and add events to it to create the debug panel.
**/
var ENSEMBL_DEBUG = 0;
function __init_ensembl_debug() {
  if( ENSEMBL_DEBUG==1 ) return;
  ENSEMBL_DEBUG = 1;
  if( $('debug') ) {
// Construct the buttons close/open button for the dialog box
  // Add the debug button which opens/closes the pages
    $('debug').appendChild(Builder.node('div',{id:'debug_button'},
      'Debug information...'
    ));
  // Add the links to clear debug messages; toggle display of
  // message types
    $('debug').appendChild(Builder.node('div',
      {id:'debug_links',className:'invis'},[
        Builder.node('span',
          {id:'debug_success',className:'debug_button'},'Success'),
        Builder.node('span',
          {id:'debug_info',   className:'debug_button'},'Info'),
        Builder.node('span',
          {id:'debug_warn',   className:'debug_button'},'Warnings'),
        Builder.node('span',
          {id:'debug_error',  className:'debug_button'},'Errors'),
        Builder.node('span',
          {id:'debug_clear',  className:'debug_button'},'Clear')
      ]
    ));
  // Add the area to include the debug messages.
    $('debug').appendChild(Builder.node('ul',
      {id:'debug_list',className:'invis'}
    ));
  // Add an on-click event to the main debug button to
  // open/close debug panel...
    Event.observe( $('debug_button'), 'click',function() {
      if($('debug_list').hasClassName(   'invis')) {
         $('debug_list').addClassName(   'vis');
         $('debug_list').removeClassName('invis');
        $('debug_links').addClassName(   'vis');
        $('debug_links').removeClassName('invis');
      } else {
         $('debug_list').addClassName(   'invis');
         $('debug_list').removeClassName('vis');
        $('debug_links').addClassName(   'invis');
        $('debug_links').removeClassName('vis');
      }
    });
  // Add an on click event to the buttons to toggle the display of
  // messages of given class..
    $$('.debug_button').each(function(but) {
      Event.observe( but, 'click', _debug_press );
    });
  }
}

// Call initialisation function on page load
Event.observe(window, 'load', __init_ensembl_debug )

