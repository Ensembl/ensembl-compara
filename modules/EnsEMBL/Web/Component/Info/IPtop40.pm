package EnsEMBL::Web::Component::Info::IPtop40;

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
  my $file = '/ssi/species/stats_' . $self->hub->species . '_IPtop40.html';
  return EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $file);
}

1;
