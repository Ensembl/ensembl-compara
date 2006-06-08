package Bio::EnsEMBL::GlyphSet::info;
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

  my $Config        = $self->{'config'};
  my $text_to_display = sprintf( "Ensembl %s    %s:%d-%d    %s",
    @{[$self->{container}{_config_file_name_}]}, $self->{'container'}->seq_region_name,
    $self->{'container'}->start(), $self->{'container'}->end,
    scalar( gmtime() )
  );

  my( $FONT,$FONTSIZE)  = $self->get_font_details( 'text' );
  my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, $text_to_display, '', 'ptsize' => $FONTSIZE, 'font' => $FONT );

  $self->push( new Sanger::Graphics::Glyph::Text({
    'x'         => 1,
    'y'         => 1,
    'height'    => $th,
    'font'      => $FONT,
    'ptsize'    => $FONTSIZE,
    'colour'    => 'black',
    'halign'    => 'left',
    'text'      => $text_to_display,
    'absolutey' => 1,
  }) );
}

1;
        
