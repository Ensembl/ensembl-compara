=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::File::Dynamic::Image;

use strict;

use parent qw(EnsEMBL::Web::File::Dynamic);

### Replacement for EnsEMBL::Web::TmpFile::Image
### Data can be written to disk or, if enabled and appropriate, memcached

sub new {
### @constructor
  my ($class, %args) = @_;
  ## If writing to disk, use the same directory for images and related content,
  ## to make cleanup easier
  $args{'extension'}  = 'png';
  $args{'drivers'}    = [qw(Memcached IO)]; 
  return $class->SUPER::new(%args);
}

1;

