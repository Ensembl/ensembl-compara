package EnsEMBL::Web::Controller::Command::Account::LogOut;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;
  my $url = $cgi->param('_referer') || '/Account/Login';
warn "URL $url";

  ## setting a (blank) expired cookie deletes the current one
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
  $user_cookie->clear($r);

  $cgi->redirect($url);
}

}

1;
