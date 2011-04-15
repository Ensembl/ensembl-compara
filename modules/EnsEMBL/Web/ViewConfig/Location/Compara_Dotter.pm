# $Id$

package EnsEMBL::Web::ViewConfig::dotterview;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->_set_defaults(qw(
    w  5000
    t  48
    g  1
    h -1
  ));
  
  $self->storable = 1;
}

1;
