# $Id$

package EnsEMBL::Web::Component::Variation::VariationSummary;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  return ''; # Currently not in use
}


1;
