=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# $Id$

package EnsEMBL::Web::Configuration::Blast;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'Search';
}

sub populate_tree {
  my $self = shift;
  
  $self->create_node('Search',   'New Search',      [qw(search   EnsEMBL::Web::Component::Blast::Search)]);
  $self->create_node('Retrieve', 'Retrieve Ticket', [qw(retrieve EnsEMBL::Web::Component::Blast::Retrieve)]);
  
  ## Add "invisible" nodes used by interface but not displayed in navigation
  $self->create_node('Submit',          '', [qw(sent    EnsEMBL::Web::Component::Blast::Submit )]);
  $self->create_node('Ticket',          '', [qw(ticket  EnsEMBL::Web::Component::Blast::Ticket)]);
  $self->create_node('Raw',             '', [qw(raw     EnsEMBL::Web::Component::Blast::Raw )]);
  $self->create_node('View',            '', [qw(view    EnsEMBL::Web::Component::Blast::View)]);
  $self->create_node('Alignment',       '', [qw(align   EnsEMBL::Web::Component::Blast::Alignment )]);
  $self->create_node('QuerySequence',   '', [qw(query   EnsEMBL::Web::Component::Blast::QuerySequence)]);
  $self->create_node('GenomicSequence', '', [qw(genomic EnsEMBL::Web::Component::Blast::GenomicSequence)]);
}

1;
