=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::QueryStore::Cache::Memcached;

use strict;
use warnings;

use Cache::Memcached;

sub new {
  my ($proto,$conf) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    cache => Cache::Memcached->new($conf)
  };
  bless $self,$class;
  return $self;
}

sub set {
  my ($self,$class,$ver,$k,$v) = @_;

  $self->{'cache'}->set($self->_key($k,$class,$ver),$v);
}

sub get {
  my ($self,$class,$ver,$k) = @_;

  return $self->{'cache'}->get($self->_key($k,$class,$ver));
}

1;
