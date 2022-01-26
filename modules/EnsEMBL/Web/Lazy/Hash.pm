=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Lazy::Hash;

use strict;
use warnings;

use Tie::Hash;

use base qw(Tie::StdHash);

use Exporter qw(import);

our @EXPORT_OK = qw(lazy_hash);

# Creates a tied hash where sets can be subs which before they are
# got are executed.

sub get { $_[0]->FETCH($_[1]); }

sub FETCH {
  my ($self,$k) = @_;

  $self->{$k} = $self->{$k}->($self) if ref($self->{$k}) eq 'CODE';
  return $self->{$k};
}

sub lazy_hash {
  my ($hashref) = @_;

  tie my %magic,'EnsEMBL::Web::Lazy::Hash';
  %magic = %$hashref;
  return \%magic;
}

1;

