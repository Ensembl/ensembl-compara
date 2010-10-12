# $Id$

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
  my $form  = new EnsEMBL::Web::Form('retrieve_ticket', '/Blast/Submit', 'get');
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
