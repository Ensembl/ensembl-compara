# $Id$

package EnsEMBL::Web::ViewConfig::Location::Cell_line;

use base qw(EnsEMBL::Web::ViewConfig::Cell_line);

use strict;

sub init {
  my $self = shift;
  $self->SUPER::init(@_);
  $self->has_images = 0;
}

sub update_from_input { $_[0]->SUPER::update_from_input('contigviewbottom'); }

1;
