/*
  Any clean up - nothing at the moment
*/

function __init_ensembl_rel_external() {
  $$('a[rel="external"]').each(function(n){
    n.target = '__blank';
  });
}
addLoadEvent( __init_ensembl_rel_external );

var ENSEMBL_LOAD_TIME = _time_diff(ENSEMBL_START_TIME);

function __end_of_add_on_load() {
  __info( 'On load events all fired' );
}
addLoadEvent( __end_of_add_on_load );


