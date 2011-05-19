# $Id$

package EnsEMBL::Web::ViewConfig::Location::ViewBottom;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Cell_line);

sub init {
  my $self = shift;
  
  $self->{'funcgen'} = scalar keys %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'cell_type'}{'ids'}};
  
  $self->SUPER::init if $self->{'funcgen'};
  $self->add_image_config('contigviewbottom') unless $self->hub->function eq 'Cell_line';
  $self->title = 'Region Image';
}

sub form { return $_[0]->SUPER::form if $_[0]->{'funcgen'}; }

1;
