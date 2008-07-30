/*
  Any clean up - nothing at the moment
*/

var ENSEMBL_LOAD_TIME = _time_diff(ENSEMBL_START_TIME);

function __end_of_add_on_load() {
  __info( 'On load events all fired' );
}
addLoadEvent( __end_of_add_on_load );


