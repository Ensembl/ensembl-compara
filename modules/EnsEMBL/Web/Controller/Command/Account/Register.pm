package EnsEMBL::Web::Controller::Command::Account::Register;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::User;
use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;

  ## Create basic page object
  my $cgi = $self->action->cgi;
  my $page_type = $cgi->param('no_popup') ? undef : 'Popup'; 
  my $webpage = EnsEMBL::Web::Document::Interface::simple('Account', $page_type);

  my $sd = EnsEMBL::Web::SpeciesDefs->new();
  my $help_email = $sd->ENSEMBL_HELPDESK_EMAIL;
  my $sitetype = $sd->ENSEMBL_SITETYPE;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new();
  my $data = EnsEMBL::Web::Data::User->new;
  $interface->data($data);
  $interface->discover;

  ## Customization
  ## Page components
  $interface->default_view('add');
  $interface->panel_footer({'add'=>qq(<p><strong>Register with $sitetype to bookmark your favourite pages, manage your BLAST tickets and more!</strong></p>)});
  $interface->panel_footer({'add'=>qq(<p>Need help? <a href="mailto:$help_email">Contact the helpdesk</a> &middot; <a href="/info/about/privacy.html">Privacy policy</a><p>)});
  $interface->panel_header({'preview'=>qq(<p>Please check that you have entered your details correctly, then click on the button to save them to our database and send your activation email.</p>)});
  $interface->caption({
      'add' => 'Register for '.$sitetype, 
  });
  $interface->on_success($self->url('/Account/SendActivation'));
  $interface->on_failure($self->url('/Account/RegistrationFailed'));
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->customize_element('name', 'label', 'Your name');
  $interface->customize_element('name', 'required', 'yes');
  $interface->customize_element('email', 'label', 'Your email address');
  $interface->customize_element('email', 'required', 'yes');
  $interface->customize_element('email', 'notes', "You'll use this to log in to Ensembl");
  $interface->customize_element('organisation', 'label', 'Organisation');
  $interface->element('status', {'type'=>'Hidden'});
  $interface->extra_data('record_id');
  $interface->extra_data('no_popup');
  $interface->element_order('name', 'email', 'organisation', 'status');

  ## Render page or munge data, as appropriate
  ## N.B. Force use of Configuration subclass
  $webpage->process($interface, 'EnsEMBL::Web::Configuration::Interface::Account');
}

}

1;
