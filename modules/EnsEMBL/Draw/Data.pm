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

package EnsEMBL::Draw::Data;

### The "business logic" part of the drawing code - fetches data via
### the API (or a file parser) and formats it into a simple structure
### that can be used by the Output modules

use strict;

use Bio::EnsEMBL::Registry;

sub new {
  my ($class, $config) = @_;

  my $self = {
              'features' => [],
              %$config
              };

  bless $self, $class;
  return $self;  
}

sub get_data {
### Stub
### Fetch data from a database or file
  my $self = shift;
  warn "!!! DATA FETCHING NOT IMPLEMENTED IN $self";
}

sub select_output {
### Stub
### "Translate" the track renderer (e.g. 'normal', 'collapsed', 'tiling') used in the
### main web code into the name of the drowing module which can output that style
  my $self = shift;
  warn "!!! OUTPUT SELECTION NOT IMPLEMENTED IN $self";
}

1;
