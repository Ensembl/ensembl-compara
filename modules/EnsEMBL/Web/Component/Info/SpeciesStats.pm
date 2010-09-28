package EnsEMBL::Web::Component::Info::SpeciesStats;

use strict;

use EnsEMBL::Web::Controller::SSI;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $file = '/ssi/species/stats_' . $self->hub->species . '.html';
  return EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $file);
}

1;
