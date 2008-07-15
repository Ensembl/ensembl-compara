package EnsEMBL::Web::Controller::Command::Account::Update;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub process {
  my $self = shift;

  ## Create basic page object, so we can access CGI parameters
  my $webpage = EnsEMBL::Web::Document::Interface::simple('Account', 'Popup');

  my $sd = EnsEMBL::Web::SpeciesDefs->new();
  my $help_email = $sd->ENSEMBL_HELPDESK_EMAIL;
  my $sitetype = $sd->ENSEMBL_SITETYPE;
  my $sitename = $sitetype eq 'EnsEMBL' ? 'Ensembl' : $sitetype;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new;
  $interface->data($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user);
  $interface->discover;

  ## Customization
  ## Page components
  $interface->default_view('edit');
  $interface->panel_footer({'add'=>qq(<p>Need help? <a href="mailto:$help_email">Contact the helpdesk</a> &middot; <a href="/info/about/privacy.html">Privacy policy</a><p>)});
  $interface->panel_header({'preview'=>qq(<p>Please check that you have entered your details correctly, then click on the button to save them to our database.</p>)});
  $interface->caption({'on_failure'=>'Update Failed'});
  $interface->on_success($self->url('/Account/Details'));
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->caption({'add'=>'Update your '.$sitename.' account'});
  $interface->customize_element('name', 'label', 'Your name');
  $interface->customize_element('email', 'label', "Your email address");
  $interface->customize_element('organisation', 'label', 'Organisation');
  $interface->element_order('name', 'email', 'organisation');

  ## Render page or munge data, as appropriate
  ## N.B. Force use of Configuration subclass
  $webpage->process($interface, 'EnsEMBL::Web::Configuration::Interface::Account');
}

}

1;
