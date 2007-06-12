package EnsEMBL::Web::Controller::Command::User::SendActivation;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Object::User;
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
  if ($self->filters->allow) {
    $self->process;
  } else {
    $self->render_message;
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;

  my $success = 0;
  my $user = EnsEMBL::Web::Object::User->new({
        adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor,
	      email   => $cgi->param('email'),
  });
warn "User ", $user->email;
  if ($user->email) {
    $success = 1;
    my $mailer = EnsEMBL::Web::Mailer::User->new();
    $mailer->email($user->email);
    $mailer->send_activation_email((
          'user'      => $user,
          'lost'      => $cgi->param('lost') || '',
          'group_id'  => $cgi->param('group_id') || '',
        ));
    if ($success) {
      $self->set_message(qq(<p>An email has been sent for each account associated with this address. If you do not receive a message from us within a few hours, please <a href="mailto:helpdesk\@ensembl.org">contact Helpdesk</a>.</p>));
    }
    else {
      $self->set_message(qq(<p>Sorry, we were unable to send an email to this address.</p><p>Please <a href="mailto:helpdesk\@ensembl.org">contact Helpdesk</a> for further assistance.</p>));
    }
  }
  $self->render_message;
}

}

1;
