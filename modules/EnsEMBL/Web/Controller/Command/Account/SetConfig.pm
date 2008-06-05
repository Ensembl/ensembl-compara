package EnsEMBL::Web::Controller::Command::Account::SetConfig;

### Sets a configuration as the one in current use

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  my $cgi = new CGI;

  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $config = EnsEMBL::Web::Data::Record::Configuration::User->new($cgi->param('id'));
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $config->user->id});

}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->process; 
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;

  ## Set this config as the current one
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my ($current) = $user->currentconfigs;
  $current ||= $user->add_to_currentconfigs({
    config => $cgi->param('id'),
  });

  $current->config($cgi->param('id'));
  $current->save;

  #my $current_config = EnsEMBL::Web::Data::CurrentConfig->new({id=>$current->key});
  #$current_config->config($cgi->param('id'));
  #warn "Reset id to ", $current_config->config;
  #$current_config->save;

  ## Forward to the appropriate page
  my $url = CGI::escape($cgi->param('url'));
  my $mode = $cgi->param('mode');
  my $new_url;

  if ($mode eq 'edit') {
    $new_url = $self->url('/Account/Details');
  } elsif ($url) {
    $new_url = $url;
  } else {
    my $config = EnsEMBL::Web::Data::Record::Configuration::User->new($cgi->param('id'));
    if ($config && $config->url) {
      ## get saved URL
      $new_url = $config->url;
    } else {
      ## Generic fallback
      $new_url = $self->url('/Account/Details');
    }
  }
  $cgi->redirect($new_url);
}

}

1;
