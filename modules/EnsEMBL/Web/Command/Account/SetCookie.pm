# $Id$

package EnsEMBL::Web::Command::Account::SetCookie;

use strict;
use warnings;

use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  my $user = EnsEMBL::Web::Data::User->find(email => $object->param('email'));
  my $SD = $object->species_defs;
  
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
      
      $user_cookie->create( $self->r , $user->id );
    }
  }

  ## Convert any accepted invitations to memberships
  $user->update_invitations;

  if ($object->param('activated') || ($object->param('popup') && $object->param('popup') eq 'no')) {
    my $home = $SD->ENSEMBL_STYLE->{'SITE_LOGO_HREF'} || '/'; ## URL can't be blank!
    $object->redirect($self->url($home));
  }
  else {
    ## We need to close down the popup window if using AJAX and refresh the page!
    my $r = $self->r;
    my $ajax_flag = $r && $r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest';
    
    if( $ajax_flag ) { 
      $r->content_type('text/plain');
      print '{"success":true}';
    } else {
      $object->redirect($self->url('/Account/Links'));
    }
  }
}

1;
