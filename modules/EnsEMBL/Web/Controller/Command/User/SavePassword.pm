package EnsEMBL::Web::Controller::Command::User::SavePassword;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::Object::Group;
use EnsEMBL::Web::Object::Data::Invite;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $cgi = new CGI;
  if ($cgi->param('code')) {
    $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::ActivationValid');
  }
  else {
    $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::PasswordValid');
  }
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::PasswordSecure');
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
  my $cgi = new CGI;

  my $user = EnsEMBL::Web::Object::User->new({
        adaptor  => $ENSEMBL_WEB_REGISTRY->userAdaptor,
	      email => $cgi->param('email'),
  });
  my $encrypted = $user->encrypt($cgi->param('new_password_1'));
  $user->password($encrypted);
  if ($user->status eq 'pending') {
    $user->status('active');
  }
  if ($cgi->param('record_id')) {
    my $invite = EnsEMBL::Web::Object::Data::Invite->new({id => $cgi->param('record_id')});
    my $group_id = $invite->group->id;

    my $group = EnsEMBL::Web::Object::Group->new(( adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor, id => $group_id ));
    # warn "WORKING WITH USER: " . $user->id . ": " . $user->email;
    $user->add_group($group);
  }
  $user->save;

  $cgi->redirect('/common/user/set_cookie?email='.$user->email
                  .';password='.$cgi->param('new_password_1')
                  .';url='.$cgi->param('url')
                  ,';updated=yes'
                );
}

}

1;
