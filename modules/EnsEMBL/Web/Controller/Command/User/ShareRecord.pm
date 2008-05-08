package EnsEMBL::Web::Controller::Command::User::ShareRecord;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Record;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my ($records_accessor) = grep { $_ eq $user->plural($cgi->param('type')) }
                            keys %{ $user->get_has_many };
                            
  my ($user_record) = grep { $_->id == $cgi->param('id') } @{ $user->$records_accessor };
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $user_record->user_id});
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
  my $cgi = new CGI;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my ($records_accessor) = grep { $_ eq $user->plural($cgi->param('type')) }
                            keys %{ $user->get_has_many };
  my ($user_record) = grep { $_->id == $cgi->param('id') } @{ $user->$records_accessor };

  if ($user_record) {
    my $group_record = $user_record->clone;
    $group_record->attach_owner('group');
    $group_record->webgroup_id($cgi->param('webgroup_id'));
    $group_record->save; 
  } else {
    ## TODO: error exception
  }
  
  $cgi->redirect('/common/user/account');
}

}

1;
