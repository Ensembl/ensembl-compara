package EnsEMBL::Web::Controller::Command::Account::FilterNews;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::Release;
use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  ## If edting, ensure that this record belongs to the logged-in user!
  my $cgi = $self->action->cgi;
  if ($cgi->param('id')) {
    $self->user_or_admin('EnsEMBL::Web::Data::Record::NewsFilter', $cgi->param('id'), $cgi->param('owner_type'));
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
  my $data = EnsEMBL::Web::Data::Record::NewsFilter::User->new($cgi->param('id'));
  $interface->data($data);
  $interface->discover;

  ## Set values for checkboxes
  my $release = EnsEMBL::Web::Data::Release->new($sd->ENSEMBL_VERSION);
  my @all_species = $release->species('assembly_code'=>{'!='=>''});
  my @species_list;
  my @sorted = sort {$a->common_name cmp $b->common_name} @all_species;
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
  $interface->on_success($self->url('/Account/NewsFilters'));
  $interface->on_failure($self->url('/Account/UpdateFailed'));
  $interface->script_name($self->get_action->script_name);

## Form elements
  $interface->caption({add  => 'Set news filter'});
  $interface->caption({edit => 'Edit news filter'});
  $interface->permit_delete('yes');
  #$interface->element('topic', {'type'=>'MultiSelect', 'label'=>'Topic(s)',
  #                              'values' => \@topic_list, value => ''});
  $interface->element('species', {
                                  type   => 'MultiSelect',
                                  label  => 'Species',
                                  values => \@species_list,
                                  value => ''
                                 }
  );

  $interface->element('owner_type', { type => 'Hidden'});
  $interface->element_order('species', 'owner_type');


  ## Render page or munge data, as appropriate
  $webpage->process($interface, 'EnsEMBL::Web::Configuration::Interface::Record');
}

}

1;
