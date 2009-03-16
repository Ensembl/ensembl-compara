package EnsEMBL::Web::Component::UserData::SelectFile;

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
  return 'Select File to Upload';
}

sub content {
  my $self = shift;

  my $referer = '_referer='.$self->object->param('_referer').';x_requested_with='.$self->object->param('x_requested_with');
  my $sitename = $self->object->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $self->object->data_species;

  my $form = $self->modal_form('select', "/$current_species/UserData/UploadFile", {'wizard' => 1, 'back_button' => 0});
  $form->add_notes({'heading'=>'IMPORTANT NOTE:', 'text'=>qq(We are only able to store single-species datasets, containing data on $sitename coordinate systems. There is also a 5Mb limit on data uploads. If your data does not conform to these guidelines, you can still <a href="/$current_species/UserData/AttachURL?$referer" class="modal_link">attach it to $sitename</a> without uploading.)});


  $form->add_element( type => 'String', name => 'name', label => 'Name for this upload (optional)' );

  ## Species now set automatically for the page you are on
  $form->add_element( type => 'NoEdit', name => 'show_species', label => 'Species', 'value' => $self->object->species_defs->species_label($current_species));
  $form->add_element( type => 'Hidden', name => 'species', 'value' => $current_species);

  ## Work out if multiple assemblies available
  my $assemblies = $self->get_assemblies($current_species);
  my %assembly_element = ( name => 'assembly', label => 'Assembly', 'value' => $assemblies->[0]);

  if (scalar(@$assemblies) > 1) {
    my $assembly_list = [];
    foreach my $a (@$assemblies) {
      push @$assembly_list, {'name' => $a, 'value' => $a};
    }
    $assembly_element{'type'}   = 'DropDown';
    $assembly_element{'select'} = 'select';
    $assembly_element{'values'} = $assembly_list;
  }
  else {
    $assembly_element{'type'} = 'Hidden';
  }
  $form->add_element(%assembly_element);
  $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $form->add_element( type => 'String', name => 'url', label => 'or provide file URL', size => 30 );

  return $form->render;
}

1;
