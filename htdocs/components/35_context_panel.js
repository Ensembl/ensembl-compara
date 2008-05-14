/** This Javascript module alters the search box to have a graphical
    drop down akin to the Firefox drop down on server load

    Global variables: Flag to make sure that we only populate the drop down box once!! 

    Public functions: remove_search_index(code); add_search_index(code,label);
**/

  var ENSEMBL_TRANSCRIPT_DROPDOWN = 0;

  function __init_transcript_dropdown() {
/** Initialize the search box... make it a "graphical" drop down and add
    entries for Ensembl, EBI and Sanger

    PRIVATE - should only be executed once on page load
**/

    if( ENSEMBL_TRANSCRIPT_DROPDOWN==1 ) return; // Only execute once
      ENSEMBL_TRANSCRIPT_DROPDOWN = 1;

    if($('transcripts')){                    // Only if search box exists...
      __debug( 'Initializing transcript_dropdown box' );
      $('transcripts').select('tr').each(function(n){
        if( n.hasClassName('active') ) { n.show(); } else { n.hide(); }
      });
      $('transcripts').show();
      $('transcripts').setAttribute('title','Click here to show all transcript identifiers');
      Event.observe($('transcripts'),'click',function(event){
        var menu = $('transcripts');
	menu.select('tr').each(function(n) { 
	  if( n.hasClassName('active') ) { n.show(); } else { n.toggle(); }
        });
      });
      /*
      Event.observe($('transcripts_link'),'click',function(event){
        var box  = $('transcripts_link');
        var menu = $('transcripts');
        Position.clone(box,menu,{setWidth:false,offsetTop:box.getHeight()-4});
        menu.toggle();
      });
      */
// Create the search list!
    }
  }

  addLoadEvent( __init_transcript_dropdown );
