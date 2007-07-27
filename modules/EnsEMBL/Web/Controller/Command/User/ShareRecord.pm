package EnsEMBL::Web::Controller::Command::User::ShareRecord;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Record::Group;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @records = $user->find_records_by_user_record_id($cgi->param('id'), { adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor });
  my $user_record = $records[0];
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $user_record->owner});
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  $self->filters->set_action($action);
  if ($self->filters->allow) {
    $self->process;
  } else {
    $self->render_message;
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @records = $user->find_records_by_user_record_id($cgi->param('id'), { adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor });
  my $user_record = $records[0];
  my $group_record = EnsEMBL::Web::Record::Group->new(( adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor ));
  $group_record->owner($cgi->param('webgroup_id'));
  $group_record->type($user_record->type);
  ## transfer contents of 'data' field to new object
  foreach my $key (keys %{ $user_record->fields }) {
    $group_record->$key($user_record->fields->{$key});
  }
  $group_record->save; 

  $cgi->redirect('/common/user/account');
}

}

1;
