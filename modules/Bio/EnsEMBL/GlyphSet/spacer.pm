package Bio::EnsEMBL::GlyphSet::spacer;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;  
  
  $self->push($self->Rect({
    x             => $self->image_width - $self->get_parameter('image_width') + $self->get_parameter('margin'),
    y             => 0,
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
    width         => $self->my_config('width')  || 1,
    height        => $self->my_config('height') || 20,
    colour        => $self->my_config('colour'),
  }));
}

1;
