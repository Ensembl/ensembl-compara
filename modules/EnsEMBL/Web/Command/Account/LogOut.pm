package EnsEMBL::Web::Command::Account::LogOut;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  ## setting a (blank) expired cookie deletes the current one
  my $SD = $object->species_defs;
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

  $user_cookie->clear($self->r);
  $object->redirect($object->referer->{'uri'});
}

1;
