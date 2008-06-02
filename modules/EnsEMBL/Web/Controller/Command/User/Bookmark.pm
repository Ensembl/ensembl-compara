package EnsEMBL::Web::Controller::Command::User::Bookmark;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  ## If edting, ensure that this record belongs to the logged-in user!
  my $cgi = new CGI;
  my $record;
  if ($cgi->param('id')) {
    $self->user_or_admin('EnsEMBL::Web::Data::Record::Bookmark', $cgi->param('id'), $cgi->param('owner_type'));
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
  my $data;

  ## Create basic page object, so we can access CGI parameters
  my $webpage = EnsEMBL::Web::Document::Interface::simple('User');

  my $sd = EnsEMBL::Web::SpeciesDefs->new();
  my $help_email = $sd->ENSEMBL_HELPDESK_EMAIL;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new;

  ## TODO: make new constructor accept 'record_type' parameter 
  if ($cgi->param('record_type') eq 'group') {
    $data = EnsEMBL::Web::Data::Record::Bookmark::Group->new($cgi->param('id'));
  } else {
    $data = EnsEMBL::Web::Data::Record::Bookmark::User->new($cgi->param('id'));
  }
  
  $interface->data($data);
  $interface->discover;

  ## Customization
  ## Page components
  $interface->default_view('add');
  $interface->panel_footer({'add'=>qq(<p>Need help? <a href="mailto:$help_email">Contact the helpdesk</a> &middot; <a href="/info/about/privacy.html">Privacy policy</a><p>)});
  $interface->on_success($self->url('/User/_bookmark_landing'));
  $interface->on_failure($self->url('/User/UpdateFailed'));
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->caption({'add'=>'Create bookmark'});
  $interface->caption({'edit'=>'Edit bookmark'});
  $interface->permit_delete('yes');
  $interface->element('url', {'type'=>'String', 'label'=>'The URL of your bookmark'});
  $interface->element('name', {'type'=>'String', 'label'=>'Bookmark name'});
  $interface->element('description', {'type'=>'String', 'label'=>'Short description'});
  $interface->element('click', {'type'=>'Hidden'});
  $interface->element('owner_type',  { type => 'Hidden'});
  $interface->element_order(qw/name description url owner_type click/);

  ## Render page or munge data, as appropriate
  $webpage->render_message($interface, 'EnsEMBL::Web::Configuration::Interface::Record');
}

}

1;
