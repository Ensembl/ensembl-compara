=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

### MODULE AT RISK OF DELETION ##
# This module is unused in the core Ensembl code, and is at risk of
# deletion. If you have use for this module, please contact the
# Ensembl team.
### MODULE AT RISK OF DELETION ##

package EnsEMBL::Draw::GlyphSet::preliminary;

### Prints the text from ENSEMBL_PRELIM parameter
### STATUS: Unknown - appears to have been written for the 
### pre site, but doesn't seem to be in use

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);
use EnsEMBL::Web::Utils::Tombstone qw(tombstone);

sub new {
  my $self = shift;
  tombstone('2015-04-16','ds23');
  $self->SUPER::new(@_);
}

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == 1);
  return unless my $mod = $self->species_defs->ENSEMBL_PRELIM;
  my( $FONT,$FONTSIZE )  = $self->get_font_details( 'text' );
  my $top = 0;
  foreach my $line (split /\|/, $mod) { 
    my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, $line, '', 'ptsize' => $FONTSIZE, 'font' => $FONT );
    $self->push( $self->Text({
      'x'         => int( ($self->{'container'}->length()+1)/2 ), 
      'y'         => $top,
      'height'    => $th,
      'font'      => $FONT,
      'ptsize'    => $FONTSIZE,
      'colour'    => 'red3',
      'text'      => $line,
      'absolutey' => 1,
    }) );
    $top += $th + 4;
  }
}

1;
        
