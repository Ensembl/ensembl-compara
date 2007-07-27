package EnsEMBL::Web::Controller::Command::User::SetConfig;

### Sets a configuration as the one in current use

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Object::Data::User;
use EnsEMBL::Web::Object::Data::Configuration;
use EnsEMBL::Web::Object::Data::CurrentConfig;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;
  my $config = EnsEMBL::Web::Object::Data::Configuration->new({'id'=>$cgi->param('id')});
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $config->user->id});

}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->process;
  } else {
    $self->render_message; 
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;

  ## Set this config as the current one
  my $reg = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY;
  my $user_id = $reg->get_user->id;
  warn "** User $user_id";
  my $data_user = EnsEMBL::Web::Object::Data::User->new({id=>$user_id});
  my $current = $data_user->currentconfigs->[0];
  if (!$current) {
    $current = EnsEMBL::Web::Object::Data::CurrentConfig->new();
  }
  $current->config($cgi->param('id'));
  $current->save;
  #my $current_config = EnsEMBL::Web::Object::Data::CurrentConfig->new({id=>$current->key});
  #$current_config->config($cgi->param('id'));
  #warn "Reset id to ", $current_config->config;
  #$current_config->save;

  ## Forward to the appropriate page
  my $url = $cgi->param('url');
  my $mode = $cgi->param('mode');
  my $new_url;
  if ($mode eq 'edit') {
    $new_url = '/common/user/account';
  }
  elsif ($url) {
    $new_url = $url;
  }
  else {
    my $config = EnsEMBL::Web::Object::Data::Configuration->new({id=>$cgi->param('id')});
    if ($config && $config->url) {
      ## get saved URL
      $new_url = $config->url;
    }
    else {
      ## Generic fallback
      $new_url = '/common/user/account';
    }
  }
  $cgi->redirect($new_url);
}

}

1;
