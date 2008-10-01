var ensembl_body = $$('body')[0];

function __collapse( div_node ) {
  div_node.getElementsBySelector('.content').each(function(child_div){
    child_div.hide();
  });
  b_node = Builder.node( 'img', { style: 'float:left; vertical-align: top', src: '/i/closed.gif', alt:'' } );
  b_node.observe('click',function(evt){
    var el = Event.element(evt);
    var p  = el.parentNode; 
    p.getElementsBySelector('.content').each(function(child_div){
      child_div.toggle();
    });
    p.firstChild.src = p.firstChild.src.match(/closed/) ? '/i/open.gif' : '/i/closed.gif'
  });
  div_node.insertBefore(b_node,div_node.firstChild)
}

function __init_ensembl_web_expandable_panels() {
  $$('div.expandable').each( function(div_node) {
    __collapse( div_node );
  });
}
addLoadEvent(__init_ensembl_web_expandable_panels);

function __init_ensembl_web_hide_form() {
  if( $('hideform') ) {
    Event.observe($('hideform'),'click',function(event){
      $('selectform').hide();
    });
  }
}
addLoadEvent(__init_ensembl_web_hide_form );

function __init_ensembl_rel_external() {
  $$('a[rel="external"]').each(function(n){
    n.target = '__blank'
  });
}
addLoadEvent( __init_ensembl_rel_external );

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
      ' 00:00:00 GMT; path=/;'
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
if( ENSEMBL_AJAX != 'enabled' && ENSEMBL_AJAX != 'disabled' && ENSEMBL_AJAX != 'none' ) {
  ENSEMBL_AJAX = Ajax.getTransport()?'enabled':'none';
  Cookie.set('ENSEMBL_AJAX',ENSEMBL_AJAX);
}
var ENSEMBL_WIDTH = Cookie.get('ENSEMBL_WIDTH');
if( ! ENSEMBL_WIDTH ) {
  ENSEMBL_WIDTH = Math.floor( ( document.viewport.getWidth() - 200 ) /100 ) * 100;
  if(ENSEMBL_WIDTH < 500) ENSEMBL_WIDTH = 500;
  Cookie.set( 'ENSEMBL_WIDTH',ENSEMBL_WIDTH );
}
