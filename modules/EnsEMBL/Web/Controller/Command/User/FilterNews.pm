package EnsEMBL::Web::Controller::Command::User::FilterNews;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data;
use EnsEMBL::Web::Data::NewsFilter;
use EnsEMBL::Web::Data::Species;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  ## If edting, ensure that this record belongs to the logged-in user!
  my $cgi = new CGI;
  if ($cgi->param('id')) {
    $self->user_or_admin('EnsEMBL::Web::Data::NewsFilter', $cgi->param('id'), $cgi->param('record_type'));
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

  ## Create basic page object, so we can access CGI parameters
  my $webpage = EnsEMBL::Web::Document::Interface::simple('User');

  my $sd = EnsEMBL::Web::SpeciesDefs->new();
  my $help_email = $sd->ENSEMBL_HELPDESK_EMAIL;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface::InterfaceDef->new();
  my $data = EnsEMBL::Web::Data::NewsFilter->new();
  $interface->data($data);
  $interface->discover;

  ## Set values for checkboxes
  my $all_species = EnsEMBL::Web::Data::Species->find_all;
  my @species_list;
  my @sorted = sort {$a->common_name cmp $b->common_name} @$all_species;
  foreach my $species (@sorted) {
    push @species_list, {'name' => $species->common_name, 'value' => $species->name};
  }
  my @topic_list = (
      {'name' => 'Data updates', 'value' => 'data'},
      {'name' => 'Code changes', 'value' => 'code'},
      {'name' => 'API changes', 'value' => 'schema'},
      {'name' => 'Web features', 'value' => 'feature'},
    );

  ## Customization
  ## Page components
  $interface->default_view('add');
  $interface->panel_footer({'add'=>qq(<p>Need help? <a href="mailto:$help_email">Contact the helpdesk</a> &middot; <a href="/info/about/privacy.html">Privacy policy</a><p>)});
  $interface->on_success('/common/user/account');
  $interface->on_failure('/common/user/update_failed');
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->caption({'add'=>'Set news filter'});
  $interface->caption({'edit'=>'Edit news filter'});
  $interface->permit_delete('yes');
  #$interface->element('topic', {'type'=>'MultiSelect', 'label'=>'Topic(s)',
  #                              'values' => \@topic_list, value => ''});
  $interface->element('species', {'type' => 'MultiSelect', 'label' => 'Species',
                                  'values' => \@species_list, value => ''});
  $interface->element('record_type', {'type'=>'Hidden'});
  $interface->element_order('species', 'record_type');


  ## Render page or munge data, as appropriate
  $webpage->render_message($interface, 'EnsEMBL::Web::Configuration::Interface::Record');
}

}

1;
