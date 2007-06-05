package EnsEMBL::Web::Controller::Command::User::ResetPassword;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Document::Interface;
use EnsEMBL::Web::Interface::InterfaceDef;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::DataUser->new);
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::ActivationCode->new);
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  $self->filters->set_action($action);
  if ($self->filters->allow) {
    $self->render_page;
  } else {
    $self->render_message;
  }
}

sub render_page {
  my $self = shift;
  my $user = $self->filters->user($self->get_action->get_named_parameter('id'));
  warn "RENDERING PAGE";
  my $webpage = EnsEMBL::Web::Document::Interface::simple('User');
  
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new();
  my $data =EnsEMBL::Web::Object::Data::User->new();;
  $interface->data($user);
  $interface->discover;
  
  $interface->default_view('password');
  $interface->panel_header({'password'=>qq(<p>You can reset your password below.</p>)});
  $interface->on_success('EnsEMBL::Web::Component::Interface::User::saved_password');
  $interface->on_failure('EnsEMBL::Web::Component::Interface::User::failed_activation');
  $interface->caption({'on_failure'=>'Password change failed'});
  $interface->element_order('email', 'name');
  $interface->script_name('user/reset_password');
  
  $webpage->process($interface, 'EnsEMBL::Web::Configuration::Interface::User');
  
  }
  
}

1;
