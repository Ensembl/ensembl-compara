package Bio::EnsEMBL::GlyphSet::Pseparator;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Space;
use  Sanger::Graphics::Bump;

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );

  my $numchars = 16;
  my $Config   = $self->{'config'};
  my $confkey  = $self->{'extras'}->{'confkey'};
  my $text     = $self->{'extras'}->{'name'};
  my $authority= $self->{'extras'}->{'authority'} || '';
  my $colour   = $Config->get($confkey,'col') || 'black';
  my $longtext = $text;

  my $textlen = length($text);
  if( $textlen > $numchars ){ # Truncate
    $text = substr( $text, 0, 14 ).".."
  }

  my( $fontname, $fontsize ) = $self->get_font_details( 'label' );
  my @res = $self->get_text_width(0,$text,'','font'=>$fontname, 'ptsize' => $fontsize );
  $self->{'extras'}->{'x_offset'} =  $res[2] - 100;

  my $zmenu = { caption=>$longtext };
  $authority and $zmenu->{"01:Details"} = $authority;


  my $label = new Sanger::Graphics::Glyph::Text({
    'y' => 0,
    'font'      => $fontname,
    'ptsize'    => $fontsize,
    'height'    => $res[3],
    'text'      => $text,
    'colour'    => $colour,
    'absolutey' => 1,
    'zmenu'     => $zmenu
  });
  $self->label($label);
}

sub _init {
  my ($self) = @_;
	
  my $Config  = $self->{'config'};
  my $confkey = $self->{'extras'}->{'confkey'};
  my $colour  = $Config->get($confkey,'col') || 'black';
  #my $len     = $self->{'container'}->length();
  my $len     = $Config->image_width;
  my $x_offset= $self->{'extras'}->{'x_offset'};

  my $glyph = new Sanger::Graphics::Glyph::Line
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
    my $glyph2 = new Sanger::Graphics::Glyph::Space
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
