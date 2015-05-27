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

package EnsEMBL::Draw::GlyphSet::missing;

### AS FAR AS I CAN TELL, THIS GLYPHSET IS NOT IN CURRENT USE - THE
### 'TURNED OFF' MESSAGE IS RENDERED USING THE text.pm GLYPHSET

### Displays a message at the bottom of configurable images, showing
### the number of tracks that are currently turned off

use strict;
use warnings;

use base qw(EnsEMBL::Draw::GlyphSet);
use EnsEMBL::Web::Utils::Tombstone qw(tombstone);

sub new {
  my $self = shift;
  tombstone('2015-04-16','ds23');
  $self->SUPER::new(@_);
}

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);
  return unless exists( $self->{'config'}->{'missing_tracks'} );
  my $tracks   = $self->{'config'}->{'missing_tracks'};
  my $Config        = $self->{'config'};
  my( $FONT,$FONTSIZE)  = $self->get_font_details( 'text' );

  #my $text_to_display = "All tracks are currently switched on";
  my $text_to_display= "";  # temporary measure to stop incorrect info on browser until fixed properly

  if( $tracks > 1 ) {
    $text_to_display =  "There are currently $tracks tracks switched off, use the menus above the image to turn them on." ;
  } elsif( $tracks == 1 ) {
    $text_to_display =  "There is currently one track switched off, use the menus above the image to turn this on." ;
  }

  my( $txt, $bit, $w,$th ) = $self->get_text_width( 0, $text_to_display, '', 'ptsize' => $FONTSIZE, 'font' => $FONT );
 
  $self->push($self->Text({
    'x'         => 0, 
    'y'         => 1,
    'height'    => $th,
    'font'      => $FONT,
    'ptsize'    => $FONTSIZE,
    'colour'    => 'black',
    'halign'    => 'left',
    'text'      => $text_to_display,
    'absolutey' => 1,
  }));
}

1;
        
