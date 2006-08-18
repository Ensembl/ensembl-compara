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

  my $Config   = $self->{'config'};

  my $Version   = $Config->species_defs->ENSEMBL_VERSION;
  my $Assembly  = $Config->species_defs->ASSEMBLY_ID;
  my $SpVersion = $Config->species_defs->SPECIES_RELEASE_VERSION;
  my $species   = $Config->species_defs->SPECIES_BIO_NAME;
  my $sitetype  = $Config->species_defs->ENSEMBL_SITETYPE;

  my $type = $self->{'container'}->coord_system->name();
  $type = ucfirst( $type );
  my $chr = $self->{'container'}->seq_region_name();
  $chr = "$type $chr" unless $chr =~ /^$type/i;

  my $text_to_display = sprintf( "%s %s version %s.%s (%s) %s %s - %s",
    $sitetype, $species, $Version, $SpVersion, $Assembly,
    $chr,
    $self->thousandify( $self->{'container'}->start() ),
    $self->thousandify( $self->{'container'}->end )
  );

  my( $FONT,$FONTSIZE)  = $self->get_font_details( 'text' );
  my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, $text_to_display, '', 'ptsize' => $FONTSIZE, 'font' => $FONT );

  $self->push( new Sanger::Graphics::Glyph::Text({
    'x'         => 0,
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
        
