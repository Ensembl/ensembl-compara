package EnsEMBL::Web::Controller::Command::Account::Group;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data::Group;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  ## If editing, ensure that this user is an administrator of this group
  my $cgi = new CGI;
  if ($cgi->param('id')) {
    $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Admin', {'group_id' => $cgi->param('id')});
  }
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->render_page;
  }
}

sub render_page {
  my $self = shift;
  my $cgi = new CGI;

  ## Create basic page object, so we can access CGI parameters
  my $webpage = EnsEMBL::Web::Document::Interface::simple('Account');

  my $sd = EnsEMBL::Web::SpeciesDefs->new();
  my $help_email = $sd->ENSEMBL_HELPDESK_EMAIL;
  my $sitename = $sd->ENSEMBL_SITETYPE;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new;
  my $data = EnsEMBL::Web::Data::Group->new($cgi->param('id'));
  $interface->data($data);
  $interface->discover;

  ## Customization
  ## Page components
  $interface->default_view('add');
  $interface->panel_header({'add'=>qq(<p>You can create a new $sitename group from here. $sitename groups allow you to share customisations and settings between collections of users.</p><p>Setting up a new group takes about 2 minutes.</p>)});
  $interface->panel_footer({'add'=>qq(<p>Need help? <a href="mailto:$help_email">Contact the helpdesk</a> &middot; <a href="/info/about/privacy.html">Privacy policy</a><p>)});
  $interface->on_success($self->url('/Account/Details'));
  $interface->on_failure($self->url('/Account/UpdateFailed'));
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->caption({'add'=>'Create group'});
  $interface->caption({'edit'=>'Edit group details'});
  $interface->permit_delete('yes');
  $interface->element('name', {'type'=>'String', 'label'=>'Name of Group'});
  $interface->element('blurb', {'type'=>'Text', 'label'=>'Short description'});
  $interface->element_order('name', 'blurb');

  ## Render page or munge data, as appropriate
  $webpage->process($interface, 'EnsEMBL::Web::Configuration::Interface::Group');
}

}

1;
