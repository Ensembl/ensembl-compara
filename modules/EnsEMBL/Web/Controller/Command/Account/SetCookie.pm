package EnsEMBL::Web::Controller::Command::Account::SetCookie;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Tools::Encryption;
use EnsEMBL::Web::RegObj;
use Apache2::RequestUtil;
use CGI qw(header);

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::PasswordValid');
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  my $user = EnsEMBL::Web::Data::User->find(email => $cgi->param('email'));
  #warn "Setting cookie for user ".$user->name;
  
  if (!$ENV{'ENSEMBL_USER_ID'}) {
    if ($user && $user->id) {
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

  if ($cgi->param('activated')) {
    my $style = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_STYLE;
    my $home = $style->{'SITE_LOGO_HREF'} || '/';
    $cgi->redirect($self->url($home));
  }
  else {
    my $new_param = {};
    if ($cgi->param('updated')) {
      $new_param->{'updated'} = $cgi->param('updated');
    }
### We need to close down the popup window if using AJAX and refresh the page!
### we know how to do this from the configurator!
    my $r = Apache2::RequestUtil->request();
    my $ajax_flag = $r && (
      $r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest'||
      $cgi->param('x_requested_with') eq 'XMLHttpRequest'
    );
    if( $ajax_flag ) { 
      header( 'text/plain' );
      print "SUCCESS";
    } else {
      $cgi->redirect($self->url('/Account/Links', $new_param));
    }
  }
}

}

1;
