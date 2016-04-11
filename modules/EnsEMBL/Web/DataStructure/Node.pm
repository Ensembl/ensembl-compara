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

package EnsEMBL::Web::DataStructure::Node;

use strict;
use warnings;

sub new {
  my ($class, $obj) = @_;

  return $obj, ref $class || $class;
}

sub set {
  my ($self, $key, $val) = @_;

  return if $key =~ /^__ds_/;
  return $self->{$key} = $val;
}

sub get {
  my ($self, $key) = @_;

  return if $key =~ /^__ds_$/;
  return $self->{$key};
}

1;
