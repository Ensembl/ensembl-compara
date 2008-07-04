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
