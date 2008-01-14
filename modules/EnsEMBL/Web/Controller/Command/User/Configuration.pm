package EnsEMBL::Web::Controller::Command::User::Configuration;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data::Configuration;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  ## If editing, ensure that this record is editable by the logged-in user!
  my $cgi = new CGI;
  my $record;
  if ($cgi->param('id')) {
    $self->user_or_admin('EnsEMBL::Web::Data::Configuration', $cgi->param('id'), $cgi->param('record_type'));
  }
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

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new();
  my $data = EnsEMBL::Web::Data::Configuration->new();
  $interface->data($data);
  $interface->discover;

  ## Customization
  ## Page components
  $interface->default_view('add');
  $interface->panel_footer({'add'=>qq(<p>Need help? <a href="mailto:$help_email">Contact the helpdesk</a> &middot; <a href="/info/about/privacy.html">Privacy policy</a><p>)});
  $interface->on_success('/common/user/config_landing');
  $interface->on_failure('/common/user/update_failed');
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->caption({'add'=>'Save configuration'});
  $interface->caption({'edit'=>'Edit configuration'});
  $interface->permit_delete('yes');
  $interface->element('name', {'type'=>'String', 'label'=>'Configuration name'});
  $interface->element('description', {'type'=>'Text', 'label'=>'A brief description of your configuration'});
  $interface->element('url', {'type'=>'Hidden'});
  $interface->element('scriptconfig', {'type'=>'Hidden'});
  $interface->element('record_type', {'type'=>'Hidden'});
  $interface->extra_data('rename');
  $interface->element_order('name', 'description', 'url', 'scriptconfig', 'record_type');

  ## Render page or munge data, as appropriate
  $webpage->process($interface, 'EnsEMBL::Web::Configuration::Interface::Record');
}

}

1;
