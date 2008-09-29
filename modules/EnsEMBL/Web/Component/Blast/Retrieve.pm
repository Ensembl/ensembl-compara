package EnsEMBL::Web::Component::Blast::Retrieve;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Blast);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $html = qq(<h2>Retrieve Blast Ticket</h2>);

  my $form = EnsEMBL::Web::Form->new( 'blastticket', "/Blast/Ticket", 'get' );

  $form->add_element(
    'type'    => 'String',
    'name'    => 'ticket',
    'label'   => 'Ticket number',
  );

  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Retrieve',
  );

  $html .= $form->render;

  return $html;
}

1;
