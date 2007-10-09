package EnsEMBL::Web::Controller::Command::Help::Results;

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
  if ($self->filters->allow) {
    $self->process;
  } else {
    $self->render_message;
  }
}

sub process {
  my $self = shift;

  ## Do search
  my $webpage= new EnsEMBL::Web::Document::WebPage(
      'doctype'    => 'Popup',
      'renderer'   => 'Apache',
      'outputtype' => 'HTML',
      'scriptname' => 'help/results',
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
  my @results = @{$object->search};
  my $total = scalar(@results);
  if ($total < 1) { 
    $webpage->redirect('/common/help/contact?kw='.$object->param('kw'));
  }
  elsif ($total == 1) {
    my $article = $results[0];
    $webpage->redirect('/common/helpview?id='.$article->id.';hilite='.$object->param('hilite'));
  }
  else {
    $webpage->configure( $object, 'results', 'context_menu' );
    $webpage->action();
  }
  
}

}

1;
