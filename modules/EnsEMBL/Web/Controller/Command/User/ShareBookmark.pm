package EnsEMBL::Web::Controller::Command::User::ShareBookmark;

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::DataUser');
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->render_page;
  } else {
    $self->render_message;
  }
}

sub render_page {
  my $self = shift;

  my $webpage = EnsEMBL::Web::Document::Interface::simple('User');

  my $sd = EnsEMBL::Web::SpeciesDefs->new();
  my $help_email = $sd->ENSEMBL_HELPDESK_EMAIL;
  my $sitetype = $sd->ENSEMBL_SITETYPE;
  my $sitename = $sitetype eq 'EnsEMBL' ? 'Ensembl' : $sitetype;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new();

  ## Customization
  ## Page components
  $interface->default_view('add');
  $interface->panel_header({'preview'=>qq(<p>Select a group to share your record with</p>)});
  $interface->on_success('/common/user/activate');
  $interface->on_failure('EnsEMBL::Web::Component::Interface::User::failed_registration');
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->caption({'add'=>'Register for '.$sitename});
  $interface->customize_element('name', 'label', 'Your name');
  $interface->customize_element('email', 'label', "Your email address. You'll use this to log in to Ensembl");
  $interface->customize_element('organisation', 'label', 'Organisation');
  $interface->element_order('name', 'email', 'organisation');

  ## Render page or munge data, as appropriate
  ## N.B. Force use of Configuration subclass
  $webpage->process($interface, 'EnsEMBL::Web::Configuration::Interface::User');

}

}

1;
