package EnsEMBL::Web::Controller::Command::Account::Group;

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
    $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Admin',
        {'group_id' => $cgi->param('id')}
    );
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
  my $data = EnsEMBL::Web::Data::Group->new($cgi->param('id'));
  
  $interface->data($data);
  $interface->discover;

  ## Customization
  ## Page components
  $interface->default_view('add');
  $interface->panel_footer({'add'=>qq(<p>Need help? <a href="mailto:$help_email">Contact the helpdesk</a> &middot; <a href="/info/about/privacy.html">Privacy policy</a><p>)});
  $interface->on_success($self->url('/Account/AdminGroups?_referer='.$cgi->param('_referer')));
  $interface->on_failure($self->url('/Account/UpdateFailed?_referer='.$cgi->param('_referer')));
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->caption({add  => 'Save group'});
  $interface->caption({edit => 'Edit group'});
  $interface->permit_delete('yes');
  $interface->element('name',         { type => 'String', label => 'Group name'});
  $interface->element('blurb',  { type => 'Text',   label => 'A brief description of your group'});
  $interface->element_order(qw/name blurb/);

  ## Render page or munge data, as appropriate
  $webpage->process($interface, 'EnsEMBL::Web::Configuration::Interface::Group');
}

}

1;
