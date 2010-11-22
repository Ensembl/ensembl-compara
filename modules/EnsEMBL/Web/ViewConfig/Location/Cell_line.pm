package EnsEMBL::Web::ViewConfig::Location::Cell_line;

use base qw(EnsEMBL::Web::ViewConfig::Cell_line);

use strict;

sub init {
  my $self = shift;
  $self->SUPER::init(@_);
  $self->has_images = 0;
}

1;
