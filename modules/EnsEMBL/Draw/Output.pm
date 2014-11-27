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

package EnsEMBL::Draw::Output;

### Base package for drawing a discreet section of a genomic image,
### such as a section of assembly, feature track, scalebar or track legend
### Uses GD and the EnsEMBL::Draw::Glyph codebase to render data that's 
### been passed in from a controller

use strict;

use GD;
use GD::Simple;
use URI::Escape qw(uri_escape);
use POSIX qw(floor ceil);

use Ensembl::Draw::Glyph::Circle;
use Ensembl::Draw::Glyph::Composite;
use Ensembl::Draw::Glyph::Poly;
use Ensembl::Draw::Glyph::Triangle;

sub new {
  my ($class, $data, $config) = @_;

  my $self = {
              'data' => $data,
              %$config
              };

  bless $self, $class;
  return $self;
}

sub render {
### Stub
### Render data into a track
  my $self = shift;
  warn "!!! RENDERING NOT IMPLEMENTED IN ".ref($self);
};

sub image_config {
  my $self = shift;
  return $self->{'config'};
}

sub track_config {
  my $self = shift;
  return $self->{'my_config'};
}

1;

