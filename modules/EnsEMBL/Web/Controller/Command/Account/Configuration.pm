package EnsEMBL::Web::Controller::Command::Account::Configuration;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  ## If editing, ensure that this record is editable by the logged-in user!
  my $cgi = $self->action->cgi;
  my $record;
  if ($cgi->param('id')) {
    $self->user_or_admin('EnsEMBL::Web::Data::Record::Configuration', $cgi->param('id'), $cgi->param('owner_type'));
  }
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  ## Create basic page object, so we can access CGI parameters
  my $webpage = EnsEMBL::Web::Document::Interface::simple('Account', 'Popup');

  my $sd = EnsEMBL::Web::SpeciesDefs->new();
  my $help_email = $sd->ENSEMBL_HELPDESK_EMAIL;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new;
  my $data;
  if ($cgi->param('record_type') && $cgi->param('record_type') eq 'group') {
    $data = EnsEMBL::Web::Data::Record::Configuration::Group->new($cgi->param('id'));
  } else {
    $data = EnsEMBL::Web::Data::Record::Configuration::User->new($cgi->param('id'));
  }
  
  $interface->data($data);
  $interface->discover;

  ## Customization
  ## Page components
  $interface->default_view('add');
  $interface->panel_footer({'add'=>qq(<p>Need help? <a href="mailto:$help_email">Contact the helpdesk</a> &middot; <a href="/info/about/privacy.html">Privacy policy</a><p>)});
  $interface->on_success($self->url('/Account/ConfigLanding'));
  $interface->on_failure($self->url('/Account/UpdateFailed'));
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->caption({add  => 'Save configuration'});
  $interface->caption({edit => 'Edit configuration'});
  $interface->permit_delete('yes');
  $interface->element('name',         { type => 'String', label => 'Configuration name'});
  $interface->element('description',  { type => 'Text',   label => 'A brief description of your configuration'});
  $interface->element('url',          { type => 'Hidden'});
  $interface->element('viewconfig', { type => 'Hidden'});
  $interface->element('owner_type',   { type => 'Hidden'});
  $interface->extra_data('rename');
  $interface->element_order(qw/name description url viewconfig owner_type/);

  ## Render page or munge data, as appropriate
  $webpage->process($interface, 'EnsEMBL::Web::Configuration::Interface::Record');
}

}

1;
