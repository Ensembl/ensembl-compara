package Bio::EnsEMBL::GlyphSet::Pseparator;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use  Sanger::Graphics::Bump;

sub _init {
  my ($self) = @_;
	
  my $Config  = $self->{'config'};
  my $confkey = $self->{'extras'}->{'confkey'};
  my $colour  = $Config->get($confkey,'col') || 'black';
  #my $len     = $self->{'container'}->length();
  my $len     = $Config->image_width;
  my $x_offset= $self->{'extras'}->{'x_offset'};

  my $glyph = $self->Line
    ({
      'x'             => $x_offset,
      'y'             => 6,
      'width'         => $len - $x_offset,
      'height'        => 0,
      'colour'        => $colour,
      'absolutey'     => 1,
      'absolutex'     => 1,
      'absolutewidth' => 1,
      'dotted'        => 1,
     });
  $self->push($glyph);

  if( length( $self->{'extras'}->{'name'} ) ){
    my $glyph2 = $self->Space
      ({
        'x'         => 0,
        'y'         => 0,
        'width'     => 1,
        'height'    => 12,
        'absolutey' => 1,
       });
    $self->push($glyph2);
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
