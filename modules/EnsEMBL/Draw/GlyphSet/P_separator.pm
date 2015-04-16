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

package EnsEMBL::Draw::GlyphSet::P_separator;

### Draws a line 
### STATUS: Unknown - doesn't appear to be used

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
