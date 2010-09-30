package EnsEMBL::Web::Command::Account::LogOut;

use strict;

use EnsEMBL::Web::Cookie;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub  = $self->hub;

  ## setting a (blank) expired cookie deletes the current one
  my $species_defs = $hub->species_defs;
  my $user_cookie  = new EnsEMBL::Web::Cookie({
        'host'    => $species_defs->ENSEMBL_COOKIEHOST,
        'name'    => $species_defs->ENSEMBL_USER_COOKIE,
        'value'   => '',
        'env'     => 'ENSEMBL_USER_ID',
        'hash'    => {
          'offset'  => $species_defs->ENSEMBL_ENCRYPT_0,
          'key1'    => $species_defs->ENSEMBL_ENCRYPT_1,
          'key2'    => $species_defs->ENSEMBL_ENCRYPT_2,
          'key3'    => $species_defs->ENSEMBL_ENCRYPT_3,
          'expiry'  => $species_defs->ENSEMBL_ENCRYPT_EXPIRY,
          'refresh' => $species_defs->ENSEMBL_ENCRYPT_REFRESH
        }

  });
  
  $user_cookie->clear($self->r);
  $hub->redirect($hub->referer->{'uri'});
}

1;
