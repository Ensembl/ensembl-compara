package EnsEMBL::Web::Controller::Command::Help::SendEmail;

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
    $self->process;
  }
}

sub process {
  my $self = shift;

  ## Do search
  my $webpage= new EnsEMBL::Web::Document::WebPage(
      'doctype'    => 'Popup',
      'renderer'   => 'Apache',
      'outputtype' => 'HTML',
      'scriptname' => 'help/send_email',
      'objecttype' => 'Help',
  );

  my $object;
  if( $webpage->has_a_problem() ) {
    $webpage->render_error_page( $webpage->problem->[0] );
  } else {
    foreach my $obj( @{$webpage->dataObjects} ) {
      $object = $obj;
    }
  }
 
  $object->send_email;
   
  $webpage->configure( $object, 'thanks', 'context_menu' );
  $webpage->action();
  
}

}

1;
