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

/***********************************************************************
** Simplified cookie class - used to set standard Ensembl cookies for
** later retrieval - path is always set to "/" and expiry date is set
** to january 2038 (end of 32bit time)
***********************************************************************/

function _cookie_print() {
  __info( "DOC "+ document.cookie );
}

addLoadEvent( _cookie_print );

function __hide_hint() {

}

var hints_cookie = new Hash();
function hints_onload() {
  var t = Cookie.get('ENSEMBL_HINTS');
  if( t ) t.split(/:/).each(function(x){
    hints_cookie.set( x, 1 );
  });

  $$(('.hint_flag')).each(function(n){
    var name = n.id;
    if( hints_cookie.get(name) ) {
      n.hide();
    } else {
      var but = Builder.node('a', { },
        [ Builder.node('img', { 
          style: 'float:right; vertical-align: top', src: '/i/close.gif', alt:'Hide hint panel', title:'Hide hint panel'
        } ) ]
      );
      var hnode = n.firstChild;
      hnode.insertBefore( but, hnode.firstChild );
      Event.observe(but,'click',function(evt){
        var el = Event.findElement(evt,'div');
        el.hide();
        hints_cookie.set( el.id, '' );
        Cookie.set('ENSEMBL_HINTS',hints_cookie.keys().join(':') );
      });
    }
    n.removeClassName( 'hint_flag' );
  });
}

addLoadEvent( hints_onload );
