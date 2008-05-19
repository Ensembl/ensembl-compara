package EnsEMBL::Web::ScriptConfig::ajax-test;

use strict;
no strict 'refs';

sub init {
  my( $script_config ) = @_;

  $script_config->_set_defaults(qw(
    zoom_width     100
    image_width    800
    context    1000
  ));
}
1;
