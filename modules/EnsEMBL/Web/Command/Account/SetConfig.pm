package EnsEMBL::Web::Command::Account::SetConfig;

### Sets a configuration as the one in current use

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;

  ## Set this config as the current one
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my ($current) = $user->currentconfigs;
  $current ||= $user->add_to_currentconfigs({
    config => $object->param('id'),
  });

  $current->config($object->param('id'));
  $current->save;

  #my $current_config = EnsEMBL::Web::Data::CurrentConfig->new({id=>$current->key});
  #$current_config->config($object->param('id'));
  #warn "Reset id to ", $current_config->config;
  #$current_config->save;

  ## Forward to the appropriate page
  my $url = CGI::escape($object->param('url'));
  my $mode = $object->param('mode');
  my $new_url;

  if ($mode eq 'edit') {
    $new_url = $self->url('/Account/Details');
  } elsif ($url) {
    $new_url = $url;
  } else {
    my $config = EnsEMBL::Web::Data::Record::Configuration::User->new($object->param('id'));
    if ($config && $config->url) {
      ## get saved URL
      $new_url = $config->url;
    } else {
      ## Generic fallback
      $new_url = $self->url('/Account/Details');
    }
  }
  $object->redirect($new_url);
}

}

1;
