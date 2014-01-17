=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::ColourMap;
use strict;
use base qw(Sanger::Graphics::ColourMap);

sub new {
  my $class = shift;
  my $species_defs = shift;
  my $self = $class->SUPER::new( @_ );

  my %new_colourmap = qw(
    CONTRAST_BORDER   background0
    CONTRAST_BG       background3

    IMAGE_BG1         background1
    IMAGE_BG2         background2

    CONTIGBLUE1       contigblue1
    CONTIGBLUE2       contigblue2

    HIGHLIGHT1        highlight1
    HIGHLIGHT2        highlight2
  );
  while(my($k,$v) = each %{$species_defs->ENSEMBL_STYLE||{}} ) {
    my $k2 = $new_colourmap{ $k };
    next unless $k2;
    $self->{$k2} = $v;
  }
  return $self;
}

1;
