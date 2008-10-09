/**------------------------------------------------------------------------
| Initialize the display of the float box...                              |
------------------------------------------------------------------------**/

  function __float_highlight( dl_node ) {
    if( !dl_node                          ) return;
    if( dl_node.hasClassName( 'munged' ) ) return;
    var N=0;
    dl_node.immediateDescendants().each(function(dd_node) {
      if( dd_node.tagName == 'DD' ) {
        dd_node.addClassName('notl');
        var flip = 0;
        var name = 'leaf';
     
        if( dd_node.hasClassName( 'open' ) ) {
          if( dd_node.select('dl').length > 0 ) {
            name = 'open';
            flip = 1;
          } else {
            dd_node.removeClassName('open');
          }
        }
        if( dd_node.hasClassName( 'closed' ) ) {
          if(  dd_node.select('dl').length > 0 ) {
            dd_node.toggleClassName('_closed');
            flip = 1;
            name = 'closed';
          }
          dd_node.toggleClassName('closed');
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
    dl_node.addClassName('munged');
  }
  function __init_ensembl_web_float_box() {
    __debug( 'setting up menu', 'success' );
    __float_highlight( $('local_modal') );
    __float_highlight( $('local') );
  }
  
  addLoadEvent( __init_ensembl_web_float_box );
