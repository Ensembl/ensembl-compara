=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::info;

### Writes the species, assembly version and coordinate information 
### at bottom of Region in Detail

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

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
        
