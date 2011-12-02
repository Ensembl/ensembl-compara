package EnsEMBL::Web::Configuration::Experiment;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub caption { return 'Experiment View'; }

sub populate_tree {
  my $self = shift;
  my $hub  = $self->hub;

  $self->create_node('Sources', 'Sources', [qw(feature EnsEMBL::Web::Component::Experiment::Features)], { 'availability' => 1 });
}

1;
