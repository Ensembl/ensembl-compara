package EnsEMBL::Web::Controller::Command::User::SetCookie;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Tools::Encryption;
use EnsEMBL::Web::RegObj;
use Apache2::RequestUtil;
use CGI;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::PasswordValid');
}

sub render {
warn "Doing cookie setting";
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
warn "Not allowed!";
    $self->render_message;
  } else {
    $self->process;
  }
}

sub process {
  my $self = shift;

  my $cgi = new CGI;
  my $user = EnsEMBL::Web::Data::User->find(email => $cgi->param('email'));
  
  my $url = CGI::escape($cgi->param('url')); 
  if (!$url || $url =~ m#User#) { ## Don't want to redirect user to e.g. register or login confirmation!
    $url = $self->url('/index.html');
  }
  
  if (!$ENV{'ENSEMBL_USER_ID'}) {
    if ($user && $user->id) {
      my $encrypted = EnsEMBL::Web::Tools::Encryption::encryptID($user->id);
      my $SD = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs;
      my $user_cookie = EnsEMBL::Web::Cookie->new({
        'host'    => $SD->ENSEMBL_COOKIEHOST,
        'name'    => $SD->ENSEMBL_USER_COOKIE,
        'value'   => '',
        'env'     => 'ENSEMBL_USER_ID',
        'hash'    => {
          'offset'  => $SD->ENSEMBL_ENCRYPT_0,
          'key1'    => $SD->ENSEMBL_ENCRYPT_1,
          'key2'    => $SD->ENSEMBL_ENCRYPT_2,
          'key3'    => $SD->ENSEMBL_ENCRYPT_3,
          'expiry'  => $SD->ENSEMBL_ENCRYPT_EXPIRY,
          'refresh' => $SD->ENSEMBL_ENCRYPT_REFRESH
        }
      });
      my $r = Apache2::RequestUtil->request();
      $user_cookie->create( $r , $user->id );
    }
  }

=pod
  ## Add membership if coming from invitation acceptance
  if ($cgi->param('record_id')) {
    my $invitation = EnsEMBL::Web::Data::Record::Invite::Group->new($cgi->param('record_id'));
    my $success = $self->add_member_from_invitation($user, $invitation);
    $invitation->destroy
      if $self->add_member_from_invitation($user, $invitation);
  }
=cut

  my $new_param = {'url' => $url};
  if ($cgi->param('updated')) {
    $new_param->{'updated'} = $cgi->param('updated');
  }
  $cgi->redirect($self->url('/User/LoggedIn', $new_param));
}

}

1;
