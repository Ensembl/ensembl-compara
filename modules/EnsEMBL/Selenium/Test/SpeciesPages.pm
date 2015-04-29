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

package EnsEMBL::Selenium::Test::SpeciesPages;

### Parent for modules that test species-specific pages (e.g. Gene) 

use strict;

use parent 'EnsEMBL::Selenium::Test';

sub new {
  my ($class, %args) = @_;

  ## Check we have a species before proceeding
  return ('bug', "These tests require a species", $class, 'new') unless $args{'species'};

  my $self = $class->SUPER::new(%args);
  return $self;
}

1;
