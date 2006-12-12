package EnsEMBL::Web::ScriptConfig::multicontigview;

use strict;
no strict 'refs';

sub init {
  my( $script_config ) = @_;

  $script_config->_set_defaults(qw(
    panel_ideogram   on
    panel_top        on
    panel_bottom     on
    image_width     900
    context        1000
    opt_match       off
    opt_hcr          on
    opt_join_hcr     on
    opt_join_match   on
    opt_tblat       off
    opt_join_tblat   on
    opt_group_hcr    on
    opt_group_match  on
    opt_group_tblat off
  ));

  $script_config->add_image_configs({qw(
    thjviewbottom nodas
  )});
  $script_config->storable = 1;
}
1;
