package EnsEMBL::Web::Controller::Command::User::SendActivation;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Mailer::User;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $cgi = new CGI;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::EmailValid');
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

  my $user = EnsEMBL::Web::Data::User->new({
	      email   => $cgi->param('email'),
  });
  if ($cgi->param('record_id')) {
    $cgi->redirect('/common/user/activate?email='.$user->email.';code='.$user->salt.';url=/common/user/account;record_id='.$cgi->param('record_id'));
  }
  else {
    if ($user->email) {
      my $mailer = EnsEMBL::Web::Mailer::User->new();
      $mailer->email($user->email);
      $mailer->send_activation_email((
          'user'      => $user,
          'lost'      => $cgi->param('lost') || '',
          'group_id'  => $cgi->param('group_id') || '',
        ));
      $self->set_message(qq(<p>An email has been sent for each account associated with this address and should arrive shortly.</p><p>If you do not receive a message from us within a few hours, please check any spam filters on your email account, and <a href="mailto:helpdesk\@ensembl.org">contact Helpdesk</a> if you still cannot find the message.</p>));
    }
    $self->render_message;
  }
}

}

1;
