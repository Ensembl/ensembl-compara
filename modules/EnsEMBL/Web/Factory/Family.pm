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

package EnsEMBL::Web::Factory::Family;

### NAME: EnsEMBL::Web::Factory::Family
### Simple factory to create a family object from a stable ID

### STATUS: Stable

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Factory);

sub canLazy { return 1; }
sub createObjectsInternal {
  my $self = shift;

  my $db = $self->param('db') || 'compara';
  my $db_adaptor = $self->database($db);
  return undef unless $db_adaptor;
  my $adaptor = $db_adaptor->get_FamilyAdaptor;
  my $family = $adaptor->fetch_by_stable_id($self->param('fm'));
  return undef unless $family;
  return $self->new_object('Family', $family, $self->__data);
}



sub createObjects {
  my $self     = shift;

  my $fm = $self->param('fm');

  return $self->problem('fatal', 'Valid Family ID required', 'Please enter a valid family ID in the URL.') unless $fm;

  #my $cdb = ($gt =~ /^EGGT/) ? 'compara_pan_ensembl' : 'compara';
  my $cdb = 'compara';
  my $database = $self->database($cdb);

  return $self->problem('fatal', 'Database Error', 'Could not connect to the compara database.') unless $database;

  my $family = $database->get_FamilyAdaptor->fetch_by_stable_id($fm);

  if ($family) {
    $self->DataObjects($self->new_object('Family', $family, $self->__data));
  }
  else {
    return $self->problem('fatal', "Could not find Family $fm", "Either $fm does not exist in the current Ensembl database, or there was a problem retrieving it.");
  }

  $self->param('fm', $fm);
}

1;

