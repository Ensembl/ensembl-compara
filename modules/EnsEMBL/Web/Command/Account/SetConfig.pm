package EnsEMBL::Web::Command::Account::SetConfig;

### Sets a configuration as the one in current use

use strict;

use URI::Escape qw(uri_escape);

use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub  = $self->hub;

  ## Set this config as the current one
  my $user      = $hub->user;
  my ($current) = $user->currentconfigs;
  
  $current ||= $user->add_to_currentconfigs({
    config => $hub->param('id'),
  });
  
  $current->config($hub->param('id'));
  $current->save;

  ## Forward to the appropriate page
  my $url  = uri_escape($hub->param('url'));
  my $mode = $hub->param('mode');
  my $new_url;

  if ($mode eq 'edit') {
    $new_url = $self->url('/Account/Details');
  } elsif ($url) {
    $new_url = $url;
  } else {
    my $config = EnsEMBL::Web::Data::Record::Configuration::User->new($hub->param('id'));
    
    if ($config && $config->url) {
      ## get saved URL
      $new_url = $config->url;
    } else {
      ## Generic fallback
      $new_url = $self->url('/Account/Details');
    }
  }
  
  $hub->redirect($new_url);
}

1;
