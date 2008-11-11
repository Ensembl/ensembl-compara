package EnsEMBL::Web::Controller::Command::Account::SendActivation;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Mailer::User;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::EmailValid');
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  my $user = EnsEMBL::Web::Data::User->find(email => $cgi->param('email'));
  if ($cgi->param('record_id')) { ## Invited user
      $self->ajax_redirect(
		     $self->url('/Account/Activate', 
				{'email' => $user->email, 'code' => $user->salt, 'url' => '/Account/Details;record_id='.CGI::escape($cgi->param('record_id'))}));
  } 
  else {
    if ($user && $user->email) {
      my $mailer = EnsEMBL::Web::Mailer::User->new;
      $mailer->set_to($user->email);
      $mailer->send_activation_email(
          user      => $user,
          lost      => $cgi->param('lost') || '',
          group_id  => $cgi->param('group_id') || '',
      );
      $self->set_message(qq(<p>An email has been sent for each account associated with this address and should arrive shortly.</p><p>If you do not receive a message from us within a few hours, please check any spam filters on your email account, and <a href="mailto:helpdesk\@ensembl.org">contact Helpdesk</a> if you still cannot find the message.</p>));
    }
    ## Force this to use AJAX
    $cgi->param('x_requested_with', 'XMLHttpRequest');
    $self->render_message;
  }
}

}

1;
