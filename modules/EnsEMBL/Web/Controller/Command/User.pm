package EnsEMBL::Web::Controller::Command::User;

use strict;
use warnings;

use base 'EnsEMBL::Web::Controller::Command';

sub render_message {
  my $self = shift;

    my $webpage= new EnsEMBL::Web::Document::WebPage(
    'renderer'   => 'Apache',
    'outputtype' => 'HTML',
    'scriptname' => 'filter',
    'objecttype' => 'User',
    'command'    => $self,
  );

  if( $webpage->has_a_problem() ) {
    $webpage->render_error_page( $webpage->problem->[0] );
  } else {
    foreach my $object( @{$webpage->dataObjects} ) {
      $webpage->configure( $object, 'message' );
    }
    $webpage->render();
  }


}

sub user_or_admin {
  ### Chooses correct filter for shareable records, based on whether user or group record
  my ($self, $class, $id, $owner) = @_;
  if (EnsEMBL::Web::Root::dynamic_use(undef, $class)) { ## inherited
    if ($owner eq 'group') {
      my $record = $class->new({'id'=>$id, 'record_type'=>'group'});
      $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Admin', {'group_id' => $record->webgroup_id});
    }
    else {
      my $record = $class->new({'id'=>$id, 'record_type'=>'user'});
      $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $record->user->id});
    }
  }
}

1;
