package EnsEMBL::Web::Command::Account::LoadConfig;

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

  my @scripts = qw(contigview cytoview);

  ## This bit only applies if you want to load the config and not jump to the bookmark saved with it
  my $url = $object->param('url');
  if ($url) {
    my ($host, $params) = split(/\?/, $url);
    my (@parameters) = split(/;/, $params);
    my $new_params = "";
    foreach my $p (@parameters) {
      if ($p !~ /bottom/) {
        $new_params .= ";" . $p;
      }
    }

    $new_params =~ s/^;/\?/;
    $url = $host . $new_params;
  }

  my $session = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_session;
  $session->set_input($object);
  my $configuration = EnsEMBL::Web::Data::Record::Configuration::User->new($object->param('id'));

  my $string = $configuration->viewconfig;
  my $r = Apache2::RequestUtil->request();
  $session->create_session_id($r);
  foreach my $script_name (@scripts) {
    warn "SETTING CONFIG ", $object->param('id'), " FOR SCRIPT: " , $script_name;
    $session->set_view_config_from_string($script_name, $string);
  }
  my $new_param = {'id' => $object->param('id')};
  if ($url) {
    $new_param->{'url'} = $url;
  }
  $object->redirect($self->url('/Account/SetConfig', $new_param ););
}

}

1;
