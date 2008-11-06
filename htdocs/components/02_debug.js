/***********************************************************************
** Simplified cookie class - used to set standard Ensembl cookies for
** later retrieval - path is always set to "/" and expiry date is set
** to january 2038 (end of 32bit time)
***********************************************************************/

var Cookie = {
  set: function(name, value, expiry) {
    return ( document.cookie =
      escape(name) + '=' + escape(value || '') +
      '; expires='+ ( expiry == -1 ? 'Thu, 01 Jan 1970' : 'Tue, 19 Jan 2038' ) +
      ' 00:00:00 GMT; path=/'
    );
  },
  get: function(name) {
    var cookie = document.cookie.match(new RegExp('(^|;)\\s*' + escape(name) + '=([^;\\s]*)'));
    return cookie ? unescape(cookie[2]) : null;
  },
  unset: function(name) {
    var cookie = Cookie.get(name) || true;
    Cookie.set(name, '', -1);
    return cookie;
  }
};

// Check for a value of the ENSEMBL_AJAX cookie and set if not already set!
// either enabled/disabled...

var ENSEMBL_AJAX = Cookie.get('ENSEMBL_AJAX');
var ENSEMBL_WIDTH = Cookie.get('ENSEMBL_WIDTH');
var RESIZE_BAR  = 1;

function __set_cookies( ) {
  if( ENSEMBL_AJAX != 'enabled' && ENSEMBL_AJAX != 'disabled' && ENSEMBL_AJAX != 'none' ) {
    ENSEMBL_AJAX = Ajax.getTransport()?'enabled':'none';
    if( ENSEMBL_AJAX == 'enabled' ) {
      RESIZE_BAR = 0;
    }
    Cookie.set( 'ENSEMBL_AJAX',ENSEMBL_AJAX );
  }
  if( ! ENSEMBL_WIDTH ) {
    ENSEMBL_WIDTH = Math.floor( ( document.viewport.getWidth() - 250 ) /100 ) * 100;
    if(ENSEMBL_WIDTH < 500) ENSEMBL_WIDTH = 500;
    Cookie.set( 'ENSEMBL_WIDTH',ENSEMBL_WIDTH );
  }
}

addLoadEvent( __set_cookies );
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

var timers_hash = {};

function _debug_press(evt) {
  bu    = Event.element(evt);
  bu_id = bu.id;
  if( bu_id == 'debug_ajax' ) {
    if( bu.hasClassName(  'debug_button' ) ){
      bu.addClassName(    'debug_button_inv' );
      bu.removeClassName( 'debug_button'     );
      ENSEMBL_AJAX = 'disabled';
    } else {
      bu.addClassName(    'debug_button'     );
      bu.removeClassName( 'debug_button_inv' );
      ENSEMBL_AJAX = 'enabled';
    }
    Cookie.set( 'ENSEMBL_AJAX', ENSEMBL_AJAX );
    return;
  }
  if( bu_id == 'debug_clear' ) {
// "the clear" button is different from the rest! - it clears the list
    $('debug_list').innerHTML = '';
    return;
  } 
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

function _debug_start_time( key ) {
  timers_hash[key] = new Date();
}

function _debug_end_time( key ) {
  return _time_diff( timers_hash[key] );
}

function __debug( s,l ) {
  if($('debug_list')) {
    if(!l) l = 'info';
    var cl = "debug_"+l;
    var X = Builder.node('li',{className:cl}, "["+l+":"+_time_diff(ENSEMBL_START_TIME)+"s] "+s+"\n");
    $('debug_list').appendChild(X);
    if( $(cl).hasClassName('debug_button_inv') ) {
      X.hide();
    }
  }
}

function __debug_raw( s,l ) {
  if($('debug_list')) {
    if(!l) l = 'info'
    var cl = "debug_"+l;
    var X = Builder.node('li',{className:cl}, "["+l+":"+_time_diff(ENSEMBL_START_TIME)+"s] ");
    X.innerHTML = X.innerHTML + s+"\n";
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

function __status(s)  {
  $('debug_status').innerHTML = s;
}
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
    $('debug').appendChild(Builder.node('div',{id:'debug_button'},[
      'Debug information... (',
      Builder.node('span',{id:'debug_status'}),
      ')'
      ]
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
          {id:'debug_clear',  className:'debug_button'},'Clear'),
        Builder.node('span',
          {id:'debug_ajax',   className:ENSEMBL_AJAX=='enabled'?'debug_button':'debug_button_inv'},'AJAX')
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
    $$('.debug_button','.debug_button_inv').each(function(but) {
      Event.observe( but, 'click', _debug_press );
    });
  }
  __info( 'AJAX is '+ENSEMBL_AJAX+ '; load time is '+ENSEMBL_START_TIME+'s' );
  __info( "COOKIE: "+document.cookie );
}

// Call initialisation function on page load
addLoadEvent( __init_ensembl_debug );

/***********************************************************************

  DIAGNOSTIC JAVASCRIPT...
  
  Used exclusively by the packed tree dumper - to show/hide a
  sub-section of dumped packed file -
  
  Should probably go in a diagnostic plugin along with debug...
  
***********************************************************************/

var ENSEMBL_TREE_COLLAPSE = 0; // Only run once on page load, not
                               // on subsequent AJAX loads

function __init_collapse_tree() {
  if( ENSEMBL_TREE_COLLAPSE ) return;
  ENSEMBL_TREE_COLLAPSE = 1;
  $$("table.nested th").each(function(n){
// Make "th" clickable - so that neighbouring "td" toggles between
// visible/invisible
    Event.observe(n,'click',function(event){
      Event.element(event).nextSibling.toggle();
    });
    n.setStyle({cursor:'pointer'});
  });
}

addLoadEvent( __init_collapse_tree );
