=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Utils::Transform;

### Object to deal with the scaling of the image

use strict;
use warnings;

use EnsEMBL::Web::Attributes;

sub scalex         :AccessorMutator;
sub scaley         :AccessorMutator;
sub translatex     :AccessorMutator;
sub translatey     :AccessorMutator;
sub absolutescalex :AccessorMutator;
sub absolutescaley :AccessorMutator;

sub new {
  my ($class, $params) = @_;

  return bless {
    'scalex'          => 1,
    'scaley'          => 1,
    'translatex'      => 0,
    'translatey'      => 0,
    'absolutescalex'  => 1,
    'absolutescaley'  => 1,
    %{$params || {}}
  }, $class;
}

sub clone {
  my $self = shift;

  return bless { map { $_ => $self->{$_} } keys %$self }, ref $self;
}

1;
