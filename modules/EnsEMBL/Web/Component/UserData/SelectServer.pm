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

  my $current_species = $object->species_path($object->data_species);
  my $das_link    = qq(<a href="/info/docs/das/index.html">Distributed Annotation System</a>);
  my $url_link    = qq(<a href="$current_species/UserData/AttachURL" class="modal_link">URL</a>);
  my $upload_link = qq(<a href="$current_species/UserData/Upload" class="modal_link">upload</a>);
  my $action_url  = "$current_species/UserData/CheckServer";

  my $sitename = $self->object->species_defs->ENSEMBL_SITETYPE; 
  my $form = $self->modal_form('select_server', $action_url, {'wizard' => 1, 'back_button' => 0});
  $form->add_notes({
    'heading'=>'Tip',
    'text'=>qq($sitename supports the $das_link, a network of data sources
               accessible over the web. DAS combines the advantages of $url_link
               and $upload_link data, but requires special software.)});

  my @preconf_das = $object->get_das_servers;

  # DAS server section
  $form->add_field([{
    'type'   => 'dropdown',
    'name'   => 'preconf_das',
    'select' => 'select',
    'label'  => "$sitename DAS sources",
    'values' => \@preconf_das,
    'value'  => $object->param('preconf_das') || ''
  }, {
    'type'   => 'URL',
    'name'   => 'other_das',
    'label'  => 'or other DAS server',
    'size'   => '30',
    'value'  => $object->param('other_das') || '',
    'notes'  => '( e.g. http://www.example.com/MyProject/das )'
  }, {
    'type'   => 'String',
    'name'   => 'das_name_filter',
    'label'  => 'Filter sources',
    'size'   => '30',
    'value'  => $object->param('das_name_filter') || '',
    'notes'  => 'by name, description or URL'
  }]);

  $form->add_notes('Please note that the next page may take a few moments to load.');

  return $form->render;
}

1;
