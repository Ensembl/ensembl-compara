package EnsEMBL::Web::ScriptConfig::ldview;

use strict;
no strict 'refs';

use EnsEMBL::Web::ScriptConfig;
our @ISA = qw(EnsEMBL::Web::ScriptConfig);

sub init {
  my ($self ) = @_;

  $self->_set_defaults(qw(
    panel_options    on
    panel_image      on
    image_width      700
    context          10000
  ));
}
1;
