=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Selenium::Test::Variation;

### Generic tests for Variation pages

use strict;

use parent 'EnsEMBL::Selenium::Test::SpeciesPages';

sub new {
  my ($class, %args) = @_;

  my $self = $class->SUPER::new(%args);

  ## Abort this test set if the species has no variation data
  my $species = $self->species;
  if (!$species->{'variation_db'}) {
    return ['pass', 'Species '.$species->{'name'}.' has no variation data', $class, 'new'];
  }

  return $self;
}

sub default_url {
  my $self = shift;
  my $species = $self->species;

  return sprintf('/%s/Variation/Explore?v=%s', $species->{'name'}, $species->{'VARIATION_PARAM'});
}

1;
