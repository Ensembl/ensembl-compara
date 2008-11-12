/***********************************************************************
**                                                                    **
**  This Javascript module alters the search box to have a graphical  **
**  drop down akin to the Firefox drop down on server load            **
**                                                                    **
**    Global variables: ENSEMBL_SEARCH_BOX - Flag to make sure that   **
**                      we only populate the drop down box once!!     **
**                                                                    **
**    Public functions: remove_search_index(code);                    **
**                      add_search_index(code,label);                 **
**                                                                    **
***********************************************************************/

  var ENSEMBL_SEARCH_BOX = 0;

  function remove_search_index(code) {
/** Remove a search index entry from the drop down box (if it exists)
   
    PUBLIC - e.g. remove_search_index( 'ebi' );
**/
    var n = $('se_'+code);
    if(n) n.parentNode.removeChild(n);
  }

  function add_search_index(code,label) {
/** Add a search index entry to the drop down box

    PUBLIC - e.g. add_search_index( 'vega', 'Vega search' );

    Notes: 
    
    * The image "/i/search/{code}/.gif" should exist in the
      web-tree as a 16x16 gif
**/
    if(!$('se_mn')) return;   // Sanity check can't add to what doesn't exist!
    if($('se_'+code)) return; // Don't open up another search box with this link!
    var n = Builder.node( 'dt', { id: 'se_'+code }, [
      Builder.node( 'img', { src: '/i/search/'+code+'.gif', alt: '' } ),
      label
    ]);
    $('se_mn').appendChild( n );
// Add an onclick event to the "fake" drop down box
    Event.observe(n, 'click', function(event) {
      var el = Event.element(event);
      if(el.tagName!='DT') el = el.up('DT');
      var name = el.id.substr(3);                 // id is "se_{name}"
      $('se_im').src  = '/i/search/'+name+'.gif';
      $('se_mn').hide();
      $('se_si').value = name;
      Cookie.set( 'ENSEMBL_SEARCH',name );
    });
  }

  function __init_ensembl_web_search() {
/** Initialize the search box... make it a "graphical" drop down and add
    entries for Ensembl, EBI and Sanger

    PRIVATE - should only be executed once on page load
**/

    if( ENSEMBL_SEARCH_BOX==1 ) return; // Only execute once
      ENSEMBL_SEARCH_BOX = 1;

    if($('se_but')){                    // Only if search box exists...
      $('se').parentNode.appendChild(
        Builder.node( 'dl', {id: 'se_mn', style: 'display:none' } )
      );
      Event.observe($('se_but'),'click',function(event){
        var box  = $('se');
        var menu = $('se_mn');
        Position.clone(box,menu,{setWidth:false,offsetTop:box.getHeight()-4});
        menu.toggle();
      });
// Create the search list!
      add_search_index( 'ensembl_all', 'Ensembl search all species' );
      if( $('se_but').up('form').action.match(/\/common\/psychic/) ) {
        add_search_index( 'ensembl',     'Ensembl search' );
      } else {
        add_search_index( 'ensembl',     'Ensembl search this species' );
      }
      add_search_index( 'vega',    'Vega search'    );
      add_search_index( 'ebi',     'EBI search'     );
      add_search_index( 'sanger',  'Sanger search'  );
    }
    var name = Cookie.get( 'ENSEMBL_SEARCH' );
    if( name ) {
      $('se_im').src = '/i/search/'+name+'.gif';
      $('se_si').value = name;
    }
  }

  addLoadEvent( __init_ensembl_web_search );
