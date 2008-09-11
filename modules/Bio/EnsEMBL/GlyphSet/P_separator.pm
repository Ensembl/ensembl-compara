package Bio::EnsEMBL::GlyphSet::P_separator;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
	
  my $confkey = $self->{'extras'}->{'confkey'};
  my $colour  = $self->my_colour('col') || 'black';
  #my $len     = $self->{'container'}->length();
  my $len     = $self->image_width;
  my $x_offset= $self->{'extras'}->{'x_offset'};

  $self->push( $self->Line({
    'x'             => $x_offset,
    'y'             => 6,
    'width'         => $len - $x_offset,
    'height'        => 0,
    'colour'        => $colour,
    'absolutey'     => 1,
    'absolutex'     => 1,
    'absolutewidth' => 1,
    'dotted'        => 1,
  }));

  if( length( $self->{'extras'}->{'name'} ) ){
    $self->push($self->Space({
      'x'         => 0,
      'y'         => 0,
      'width'     => 1,
      'height'    => 12,
      'absolutey' => 1,
    }));
  }
}

#----------------------------------------------------------------------
# Returns the order corresponding to this glyphset
sub managed_name{
  my $self = shift;
  return $self->{'extras'}->{'order'} || 0;
}

#----------------------------------------------------------------------

1;
