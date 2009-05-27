package Bio::EnsEMBL::GlyphSet::spacer;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  my $Config      = $self->{'config'};  
  my $height  = $self->my_config('height') || 20;
  
  $self->push( $self->Rect({
    'x'         => 1,
    'y'         => 0,
    'width'     => 1,
    'height'    => $height,
    'absolutey' => 1,
    'absolutex' => 1,
  }));
}

1;
