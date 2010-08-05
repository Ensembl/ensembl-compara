package EnsEMBL::Web::ImageConfig::text_seq_legend;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;
  
  $self->set_parameter('show_labels', 'no');
  $self->create_menus(information => 'Information');
  $self->add_tracks('information', [ 'text_seq_legend', '', 'text_seq_legend', { display => 'normal', strand => 'f' }]);
}

1;
