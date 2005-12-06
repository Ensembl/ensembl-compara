package EnsEMBL::Web::ScriptConfig::cytoview;

use strict;
no strict 'refs';

sub init {
  my ($script_config ) = @_;

  $script_config->_set_defaults(qw(
    opt_gene_labels   on
    panel_ideogram    on
    panel_bottom      on
    image_width      700
    context        10000
  ));
}
1;
