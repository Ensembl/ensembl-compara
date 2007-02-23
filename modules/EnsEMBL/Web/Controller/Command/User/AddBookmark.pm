package EnsEMBL::Web::Controller::Command::User::AddBookmark;

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::LoggedIn->new);
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->render_page;
  } else {
    print "Content-type:text/html\n\n";
    print $self->filters->message; 
  }
}

sub render_page {
  my $self = shift;

  my $webpage= new EnsEMBL::Web::Document::WebPage(
    'renderer'   => 'Apache',
    'outputtype' => 'HTML',
    'scriptname' => 'accountview',
    'objecttype' => 'User',
  );

  if( $webpage->has_a_problem() ) {
    $webpage->render_error_page( $webpage->problem->[0] );
  } else {
    foreach my $object( @{$webpage->dataObjects} ) {
      $webpage->configure( $object, 'accountview', 'context_menu', 'user_menu' );
    }
    $webpage->action();
  }

}

}

1;
