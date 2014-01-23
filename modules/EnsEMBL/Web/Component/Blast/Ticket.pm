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

package EnsEMBL::Web::Component::Blast::Ticket;

use strict;

use EnsEMBL::Web::Form;

use base qw(EnsEMBL::Web::Component::Blast);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
  $self->configurable(0);
}

sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  my $form  = EnsEMBL::Web::Form->new('retrieve_ticket', '/Blast/Submit', 'get');
  my $table = $self->new_table;

  $form->add_element(
    type  => 'Hidden',
    name  => 'ticket',
    value => $hub->param('ticket'),
  );
  
  $form->add_element(
    type  => 'Hidden',
    name  => 'species',
    value => $hub->param('species'),
  );
  
  $form->add_element(
    type  => 'Submit',
    name  => 'submit',
    value => 'Retrieve',
  );
  
  $table->add_columns(
    { key => 'ticket',   title => 'Ticket No.', width => '30%', align => 'left' },
    { key => 'status',   title => 'Status',     width => '30%', align => 'left' },
    { key => 'retrieve', title => '',           width => '30%', align => 'left' },
  );
  
  $table->add_row({ 
    ticket   => $hub->param('ticket'), 
    status   => $hub->param('status'), 
    retrieve => $form->render, 
  });
  return '<h2>Status of search</h2>' . $table->render;
}

1;
