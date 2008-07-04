/**------------------------------------------------------------------------
| Initialize the display of the float box...                              |
------------------------------------------------------------------------**/


var FLOAT_HIGHLIGHT = 0;

  function __float_highlight( dl_node ) {
    var N=0;
    dl_node.immediateDescendants().each(function(dd_node) {
      if( dd_node.tagName == 'DD' ) {
        dd_node.addClassName('notl');
        var flip = 0;
        var name = 'leaf';
        if( dd_node.hasClassName( 'open' ) ) {
          name = 'open';
          flip = 1;
        }
        if( dd_node.hasClassName( 'closed' ) ) {
          dd_node.toggleClassName('closed');
          dd_node.toggleClassName('_closed');
          name = 'closed';
          flip = 1;
        }
        b_node = Builder.node( 'img', { src: '/i/'+name+'.gif', alt:'' } );
        dd_node.insertBefore( b_node, dd_node.firstChild );
        if( flip ) {
          b_node.onclick = function(evt){
	    if(!evt) evt=event;
            var el = Event.element(evt);
            var p  = el.parentNode; 
            p.toggleClassName('open');
            p.toggleClassName('_closed');
            el.src = '/i/'+(p.hasClassName('_closed')?'closed':'open')+'.gif';
          };
        }
	dd_node.immediateDescendants().each(function(x) { if(x.tagName=='DL') { __float_highlight(x); } });
        N = dd_node;
      }
    });
    if( N ) {
      N.removeClassName('notl');
      N.addClassName( 'last' );
    }
  }
  function __init_ensembl_web_float_box() {
    if(FLOAT_HIGHLIGHT) return;
    FLOAT_HIGHLIGHT = 1;
    __debug( 'setting up menu', 'success' );
    if( $('local') ) {
      __float_highlight( $('local') );
    }
  }
  
  addLoadEvent( __init_ensembl_web_float_box );
