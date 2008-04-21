package EnsEMBL::Web::Controller::Command::User::ShareRecord;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Group;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;

  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my ($records_accessor) = grep { $_ eq $cgi->param('type') } keys %{ $user->relations };
  ## TODO: this should use abstraction limiting facility rather then grep
  my ($user_record)      = grep { $_->id == $cgi->param('id') } $user->$records_accessor;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $user_record->user_id});
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

  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my ($records_accessor) = grep { $_ eq $cgi->param('type') } keys %{ $user->relations };
  ## TODO: this should use abstraction limiting facility rather then grep
  my ($user_record)      = grep { $_->id == $cgi->param('id') } $user->$records_accessor;

  my $group = EnsEMBL::Web::Data::Group->new($cgi->param('webgroup_id'));

  if ($user_record && $group) {
    my $add_to_accessor = 'add_to_'. $records_accessor;
    my $clone = $user_record->clone;
    $group->$add_to_accessor($user_record->clone);
  } else {
    ## TODO: error exception
  }
  
  $cgi->redirect('/common/user/account');
}

}

1;
