package EnsEMBL::Web::Controller::Command::Help::Contact;

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Controller::Command';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->render_page; 
  }
}

sub render_page {
  my $self = shift;

  my $webpage= new EnsEMBL::Web::Document::WebPage(
    'doctype'    => 'Popup',
    'renderer'   => 'Apache',
    'outputtype' => 'HTML',
    'scriptname' => 'help/contact',
    'objecttype' => 'Help',
  );

  if( $webpage->has_a_problem() ) {
    $webpage->render_error_page( $webpage->problem->[0] );
  } else {
    foreach my $object( @{$webpage->dataObjects} ) {
      $webpage->configure( $object, 'contact', 'context_menu' );
    }
    $webpage->action();
  }

}

}

1;
