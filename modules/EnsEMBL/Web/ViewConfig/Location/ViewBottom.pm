# $Id$

package EnsEMBL::Web::ViewConfig::Location::ViewBottom;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Cell_line);

sub init {
  my $self = shift;
  
  $self->{'funcgen'} = scalar keys %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'cell_type'}{'ids'}};
  
  $self->add_image_config('contigviewbottom');
  $self->title = 'Region Image';
  $self->SUPER::init if $self->{'funcgen'};
}

sub form { return $_[0]->SUPER::form if $_[0]->{'funcgen'}; }

1;
