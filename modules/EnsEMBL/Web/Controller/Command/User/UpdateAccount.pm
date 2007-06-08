package EnsEMBL::Web::Controller::Command::User::UpdateAccount;

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Logging');
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
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

  ## Create basic page object, so we can access CGI parameters
  my $webpage = EnsEMBL::Web::Document::Interface::simple('User');

  my $sd = EnsEMBL::Web::SpeciesDefs->new();
  my $help_email = $sd->ENSEMBL_HELPDESK_EMAIL;
  my $sitetype = $sd->ENSEMBL_SITETYPE;
  my $sitename = $sitetype eq 'EnsEMBL' ? 'Ensembl' : $sitetype;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new();
  my $data = EnsEMBL::Web::Object::Data::User->new({'id'=>$ENV{'ENSEMBL_USER_ID'}});
  $interface->data($data);
  $interface->discover;

  ## Customization
  ## Page components
  $interface->default_view('edit');
  $interface->panel_footer({'add'=>qq(<p>Need help? <a href="mailto:$help_email">Contact the helpdesk</a> &middot; <a href="/info/about/privacy.html">Privacy policy</a><p>)});
  $interface->panel_header({'preview'=>qq(<p>Please check that you have entered your details correctly, then click on the button to save them to our database.</p>)});
  $interface->caption({'on_failure'=>'Update Failed'});
  $interface->on_success('/common/user/account');
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->caption({'add'=>'Update your '.$sitename.' account'});
  $interface->customize_element('name', 'label', 'Your name');
  $interface->customize_element('email', 'label', "Your email address");
  $interface->customize_element('organisation', 'label', 'Organisation');
  $interface->element_order('name', 'email', 'organisation');

  ## Render page or munge data, as appropriate
  ## N.B. Force use of Configuration subclass
  $webpage->process($interface, 'EnsEMBL::Web::Configuration::Interface::User');
}

}

1;
