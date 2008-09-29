package EnsEMBL::Web::Component::Blast::Ticket;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Blast);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Document::SpreadSheet;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $html = qq(<h2>Status of search</h2>);

  my $table = EnsEMBL::Web::Document::SpreadSheet->new();

  $table->add_columns(
      {'key' => "ticket",   'title' => 'Ticket No.',  'width' => '30%', 'align' => 'left' },
      {'key' => "status",   'title' => 'Status',      'width' => '30%', 'align' => 'left' },
      {'key' => "retrieve", 'title' => '',            'width' => '30%', 'align' => 'left' },
    );



    my $form = EnsEMBL::Web::Form->new( "retrieve_ticket", "/Blast/Submit", 'get' );

    $form->add_element(
      'type'    => 'Hidden',
      'name'    => 'ticket',
      'value'   => $object->param("ticket"),
    );
    $form->add_element(
      'type'    => 'Hidden',
      'name'    => 'species',
      'value'   => $object->param("species"),
    );
    $form->add_element(
      'type'    => 'Submit',
      'name'    => 'submit',
      'value'   => 'Retrieve',
    );
    $table->add_row( { 
        'ticket'     => $object->param("ticket"), 
        'status'    => $object->param("status"), 
        'retrieve'  => $form->render, 
    } );


  $html .= $table->render;

  return $html;
}

1;
