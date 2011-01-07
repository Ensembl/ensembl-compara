package EnsEMBL::Web::Command::Account::LoadConfig;

### Sets a configuration as the one in current use

use strict;

use EnsEMBL::Web::Data::User;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self    = shift;
  my $hub     = $self->hub;
  my @scripts = qw(contigview cytoview);

  ## This bit only applies if you want to load the config and not jump to the bookmark saved with it
  my $url = $hub->param('url');
  
  if ($url) {
    my ($host, $params) = split /\?/, $url;
    my (@parameters)    = split /;/, $params;
    my $new_params      = '';
    
    foreach my $p (@parameters) {
      $new_params .= ";$p" if $p !~ /bottom/;
    }

    $new_params =~ s/^;/\?/;
    $url = $host . $new_params;
  }

  my $session = $hub->session;
  $session->set_input($hub);
  my $configuration = EnsEMBL::Web::Data::Record::Configuration::User->new($hub->param('id'));

  my $string = $configuration->viewconfig;
  $session->create_session_id;
  
  foreach my $script_name (@scripts) {
    warn "SETTING CONFIG ", $hub->param('id'), " FOR SCRIPT: ", $script_name;
  #  $session->set_view_config_from_string($script_name, $string); # function has been deleted from Session
  }
  
  my $new_param = { id => $hub->param('id') };
  $new_param->{'url'} = $url if $url;
  
  $hub->redirect($self->url('/Account/SetConfig', $new_param));
}

1;
