/**------------------------------------------------------------------------
| Initialize the display of the float box...                              |
------------------------------------------------------------------------**/

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
        N = dd_node;
      }
    });
    if( N ) {
      N.removeClassName('notl');
      N.addClassName( 'last' );
    }
  }
  function __init_ensembl_web_float_box() {
    __debug( 'setting up menu', 'success' );
    if( $('nav') ) {
      $$('#nav dl').each( function(dl_node) {
        if( !dl_node.hasClassName( 'float-level1' ) ) {
          __float_highlight( dl_node );
        }
      });
    }
  }
  
//  addLoadEvent( __init_ensembl_web_float_box );
