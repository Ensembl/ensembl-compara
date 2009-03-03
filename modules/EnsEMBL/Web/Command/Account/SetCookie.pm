package EnsEMBL::Web::Command::Account::SetCookie;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::RegObj;
use Apache2::RequestUtil;
use CGI qw(header);

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;

  my $user = EnsEMBL::Web::Data::User->find(email => $object->param('email'));
  my $SD = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs;
  
  if (!$ENV{'ENSEMBL_USER_ID'}) {
    if ($user && $user->id) {
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

  ## Convert any accepted invitations to memberships
  $user->update_invitations;

  if ($object->param('activated')) {
    $object->redirect($self->url($SD->ENSEMBL_BASEURL));
  }
  else {
    ## We need to close down the popup window if using AJAX and refresh the page!
    my $r = Apache2::RequestUtil->request();
    my $ajax_flag = $r && (
      $r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest'||
      $object->param('x_requested_with') eq 'XMLHttpRequest'
    );
    #warn "@@@ AJAX $ajax_flag";
    if( $ajax_flag ) { 
      CGI::header( 'text/plain' );
      print "SUCCESS";
    } else {
      $object->redirect($self->url('/Account/Links'));
    }
  }
}

}

1;
