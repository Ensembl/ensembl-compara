package Bio::EnsEMBL::GlyphSet::text;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    return;
}

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);

  my( $fontname, $fontsize ) = $self->get_font_details( 'text' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $h = $res[3];

  my $text = $self->my_config('text');
  unless ($text)  {  $text =  $self->{'config'}->{'text'}; }
  $self->push( new Sanger::Graphics::Glyph::Text({
    'x'         => 1, 
    'y'         => 2,
    'height'    => $h,
    'halign'    => 'left',
    'font'      => $fontname,
    'ptsize'    => $fontsize,
    'colour'    => 'black',
    'text'      => $text,
    'absolutey' => 1,
  }) );
}

1;
