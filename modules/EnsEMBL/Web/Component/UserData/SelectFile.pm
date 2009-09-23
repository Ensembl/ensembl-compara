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
  my $object = $self->object;

  my $referer = '_referer='.$object->param('_referer').';x_requested_with='.$object->param('x_requested_with');
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $object->data_species;

  my $form = $self->modal_form('select', "/$current_species/UserData/UploadFile", {'label'=>'Upload'});
  $form->add_notes({'heading'=>'IMPORTANT NOTE:', 'text'=>qq(We are only able to store single-species datasets, containing data on $sitename coordinate systems. There is also a 5Mb limit on data uploads. If your data does not conform to these guidelines, you can still <a href="/$current_species/UserData/AttachURL?$referer" class="modal_link">attach it to $sitename</a> without uploading.<br /><a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a>)});


  $form->add_element( type => 'String', name => 'name', label => 'Name for this upload (optional)' );

  ## Species now set automatically for the page you are on
  $form->add_element( type => 'NoEdit', name => 'show_species', label => 'Species', 'value' => $object->species_defs->species_label($current_species));
  $form->add_element( type => 'Hidden', name => 'species', 'value' => $current_species);

  ## Are mappings available
  my $mappings = $object->species_defs->ASSEMBLY_MAPPINGS;
  my $current_assembly = $object->species_defs->get_config($current_species, 'ASSEMBLY_NAME');
  $form->add_element(
      'type'    => 'NoEdit',
      'label'   => 'Assembly',
      'name'    => 'assembly',
      'value'   => $current_assembly,
  );
  if ($mappings && ref($mappings) eq 'ARRAY') {
    $form->add_element(
        'type'  => 'Information',
        'value' => 'If your data is not on the current assembly, you should <a href="/'.$current_species.'/UserData/SelectFeatures?_referer='.$object->param('_referer').'" class="modal_link">convert it using our assembly converter</a>',
    );
  }
=pod
    my @values = {'name' => $current_assembly, 'value' => $current_assembly};
    foreach my $string (reverse sort @$mappings) { 
      my @A = split('#|:', $string);
      my $assembly = $A[3];
      push @values, {'name' => $assembly, 'value' => $assembly};
    }
    $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'assembly',
      'label'   => "Assembly",
      'values'  => \@values,
      'select'   => 'select',
    );
  }
  else {
    $form->add_element(
      'type'    => 'NoEdit',
      'label'   => 'Assembly',
      'name'    => 'assembly',
      'value'   => $current_assembly,
    );
  }
=cut

  $form->add_element( type => 'Text', name => 'text', label => 'Paste file' );
  $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $form->add_element( type => 'String', name => 'url', label => 'or provide file URL', size => 30 );

  return $form->render;
}

1;
