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

package EnsEMBL::Draw::Utils::LocalCache;

### A simple cache module to speed up drawing code when you don't have
### memcached configured 

use strict;
use warnings;
no warnings "uninitialized";


sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self;
}

sub set {
  my ($self, $key, $value) = @_;
  return unless ($key && $value);
  $self->{$key} = $value;
}

sub get {
  my ($self, $key) = @_;
  return unless $key;
  return $self->{$key};
}

1;
