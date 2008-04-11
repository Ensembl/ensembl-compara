 
function _debug_press(evt) {
  if(!evt) evt = event;
  bu    = Event.element(evt);
  bu_id = bu.id;
  if( bu_id == 'debug_clear' ) {
    $('debug_list').innerHTML = '';
  } else {
    if( bu.hasClassName( 'debug_button' ) ){
      bu.addClassName( 'debug_button_inv' );
      bu.removeClassName( 'debug_button' );
      $$( '.'+bu_id ).each(function(n){n.hide()});
    } else {
      bu.addClassName( 'debug_button' );
      bu.removeClassName( 'debug_button_inv' );
      $$( '.'+bu_id ).each(function(n){n.show()});
    }
  }
}

var ENSEMBL_DEBUG = 0;
function __init_ensembl_debug() {
  if( ENSEMBL_DEBUG==1 ) return;
  ENSEMBL_DEBUG = 1;
  if( $('debug') ) {
    $('debug').appendChild(Builder.node('div',{id:'debug_button'},'DEBUG'));
    $('debug').appendChild(Builder.node('div',{id:'debug_links',className:'invis'},[
      Builder.node('span',{id:'debug_success',className:'debug_button'},'Success'),
      Builder.node('span',{id:'debug_info',   className:'debug_button'},'Info'),
      Builder.node('span',{id:'debug_warn',   className:'debug_button'},'Warnings'),
      Builder.node('span',{id:'debug_error',  className:'debug_button'},'Errors'),
      Builder.node('span',{id:'debug_clear',  className:'debug_button'},'Clear')
    ]));
    $('debug').appendChild(Builder.node('ul', {id:'debug_list',className:'invis'}));
    $('debug_button').onclick = function() {
      if($('debug_list').hasClassName('invis')) {
        $('debug_list').addClassName('vis'); $('debug_list').removeClassName('invis');
        $('debug_links').addClassName('vis'); $('debug_links').removeClassName('invis');
      } else {
        $('debug_list').addClassName('invis'); $('debug_list').removeClassName('vis');
        $('debug_links').addClassName('invis'); $('debug_links').removeClassName('vis');
      }
    }
    $$('.debug_button').each(function(but) { but.onclick= _debug_press });
  }
}

function __debug( s,l ) {
  if(!l) l = 'info'
  if($('debug_list')) {
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

addLoadEvent(__init_ensembl_debug )

