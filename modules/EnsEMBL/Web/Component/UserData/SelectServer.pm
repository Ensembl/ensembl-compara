package EnsEMBL::Web::Component::UserData::SelectServer;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Select a DAS server or data file';
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $current_species = $object->data_species;
  my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');

  my $das_link    = qq(<a href="/info/docs/das/index.html">Distributed Annotation System</a>);
  my $url_link    = qq(<a href="/$current_species/UserData/AttachURL?$referer" class="modal_link">URL</a>);
  my $upload_link = qq(<a href="/$current_species/UserData/Upload?$referer" class="modal_link">upload</a>);
  my $action_url  = "/$current_species/UserData/DasSources";

  my $sitename = $self->object->species_defs->ENSEMBL_SITETYPE; 
  my $form = $self->modal_form('select_server', $action_url, {'wizard' => 1, 'back_button' => 0});
  $form->add_notes({
    'heading'=>'Tip',
    'text'=>qq($sitename supports the $das_link, a network of data sources
               accessible over the web. DAS combines the advantages of $url_link
               and $upload_link data, but requires special software.)});

  my @preconf_das = $object->get_das_servers;

  # DAS server section
  $form->add_element('type'   => 'DropDown',
                     'name'   => 'preconf_das',
                     'select' => 'select',
                     'label'  => "$sitename DAS sources",
                     'values' => \@preconf_das,
                     'value'  => $object->param('preconf_das'));
  $form->add_element('type'   => 'String',
                     'name'   => 'other_das',
                     'label'  => 'or other DAS server',
                     'size'   => '30',
                     'value'  => $object->param('other_das'),
                     'notes'  => '( e.g. http://www.example.com/MyProject/das )');
  $form->add_element('type'   => 'String',
                     'name'   => 'das_name_filter',
                     'label'  => 'Filter sources',
                     'size'   => '30',
                     'value'  => $object->param('das_name_filter'),
                     'notes'  => 'by name, description or URL');
  $form->add_element('type'   => 'Information',
                     'value'  => 'Please note that the next page may take a few moments to load.');

  return $form->render;
}

1;
