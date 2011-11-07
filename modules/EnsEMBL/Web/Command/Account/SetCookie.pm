# $Id$

package EnsEMBL::Web::Command::Account::SetCookie;

use strict;

use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self         = shift;
  my $hub          = $self->hub;
  my $user         = EnsEMBL::Web::Data::User->find(email => $hub->param('email'));
  my $species_defs = $hub->species_defs;
  my $site         = $species_defs->ENSEMBL_SITE_URL;
  my $then         = $hub->param('then');
  my $url          = $then !~ /^http/ || $then =~ /^$site/ ? $then : $site;
  
  if (!$ENV{'ENSEMBL_USER_ID'}) {
    if ($user && $user->id) {
      my $user_cookie = new EnsEMBL::Web::Cookie({
        host  => $species_defs->ENSEMBL_COOKIEHOST,
        name  => $species_defs->ENSEMBL_USER_COOKIE,
        value => '',
        env   => 'ENSEMBL_USER_ID',
        hash  => {
          offset  => $species_defs->ENSEMBL_ENCRYPT_0,
          key1    => $species_defs->ENSEMBL_ENCRYPT_1,
          key2    => $species_defs->ENSEMBL_ENCRYPT_2,
          key3    => $species_defs->ENSEMBL_ENCRYPT_3,
          expiry  => $species_defs->ENSEMBL_ENCRYPT_EXPIRY,
          refresh => $species_defs->ENSEMBL_ENCRYPT_REFRESH
        }
      });
      
      $user_cookie->create($self->r , $user->id);
    }
  }

  ## Convert any accepted invitations to memberships
  $user->update_invitations;
  
  if ($hub->param('activated') || ($hub->param('popup') && $hub->param('popup') eq 'no')) {
    $hub->redirect($url);
  } else {
    ## We need to close down the popup window if using AJAX and refresh the page!
    my $r         = $self->r;
    my $ajax_flag = $r && $r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest';
    
    if ($ajax_flag) { 
      if ($url eq $then) {
        $self->ajax_redirect($url, undef, undef, undef, $hub->param('modal_tab'));
      } else {
        $r->content_type('text/plain');
        print '{"success":true}';
      }
    } else {
      $hub->redirect($url);
    }
  }
}

1;
