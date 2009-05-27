package Bio::EnsEMBL::GlyphSet::info;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);

  my $Config   = $self->{'config'};

  my $Version   = $Config->species_defs->ENSEMBL_VERSION;
  my $Assembly  = $Config->species_defs->ASSEMBLY_ID;
  my $SpVersion = $Config->species_defs->SPECIES_RELEASE_VERSION;
  my $species   = $Config->species_defs->SPECIES_BIO_NAME;
  my $sitetype  = $Config->species_defs->ENSEMBL_SITETYPE;

  my $type = ucfirst( $self->{'container'}->coord_system->name() );
  my $name = $self->{'container'}->seq_region_name();

     $name = "$type $name" unless $name =~ /^$type/i;

  my $text_to_display = sprintf( "%s %s version %s.%s (%s) %s %s - %s",
    $sitetype, $species, $Version, $SpVersion, $Assembly,
    $name,
    $self->commify( $self->{'container'}->start() ),
    $self->commify( $self->{'container'}->end )
  );

  my $details = $self->get_text_simple( $text_to_display, 'text' );

  $self->push( $self->Text({
    'x'         => 0,
    'y'         => 1,
    'height'    => $details->{'height'},
    'font'      => $details->{'font'},
    'ptsize'    => $details->{'fontsize'},
    'colour'    => 'black',
    'halign'    => 'left',
    'text'      => $text_to_display,
    'absolutey' => 1,
  }) );
}

1;
        
