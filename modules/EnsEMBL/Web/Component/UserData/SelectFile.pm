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
  my $hub = $self->hub;
  my $sd  = $hub->species_defs;
  my $html;

  my $sitename = $sd->ENSEMBL_SITETYPE;
  my $current_species = $hub->data_species;

  ## Should default to 5.0MB :)
  my $max_upload_size = sprintf("%.1f", $sd->CGI_POST_MAX / 1048576).'MB';

  my $form = $self->modal_form('select', $hub->species_path($current_species) . "/UserData/UploadFile", {'label'=>'Upload'});

  if (!$hub->param('filter_module')) { ## No errors
    $form->add_notes({'id' => 'upload_notes', 'heading' => 'IMPORTANT NOTE', 'text' => qq{
      We are only able to store single-species datasets, containing data on $sitename coordinate systems. There is also a $max_upload_size limit on data uploads. 
      If your data does not conform to these guidelines, you can still <a href="/$current_species/UserData/AttachURL" class="modal_link">attach it to $sitename</a> without uploading.<br />
      <a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a>
    }});
  }

  $form->add_element( type => 'String', name => 'name', label => 'Name for this upload (optional)' );

  ## Species is set automatically for the page you are on
  my @species;
  foreach my $sp ($sd->valid_species) {
    push @species, {'value' => $sp, 'name' => $sd->species_label($sp, 1)};
  }
  @species = sort {$a->{'name'} cmp $b->{'name'}} @species;
  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'species',
      'label'   => "Species",
      'values'  => \@species,
      'value'   => $current_species,
      'select'  => 'select',
  );

  ## Are mappings available?
  ## FIXME - reinstate auto-mapping option when we have a solution!
  my $mappings; # = $sd->ASSEMBLY_MAPPINGS;
  my $current_assembly = $sd->get_config($current_species, 'ASSEMBLY_NAME');
  if ($mappings && ref($mappings) eq 'ARRAY') {
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
      'value'   => $current_assembly,
      'select'  => 'select',
    );
    $form->add_element(
      'type'  => 'Information',
      'value' => 'Please note: if your data is not on the current assembly, the coordinates will be converted',
    );
  }
  else {
    $form->add_element(
      'type'    => 'NoEdit',
      'label'   => 'Assembly',
      'name'    => 'assembly_name',
      'value'   => $current_assembly,
    );
    $form->add_element(
      'type'    => 'Hidden',
      'name'    => 'assembly',
      'value'   => $current_assembly,
    );
  }

  $self->add_file_format_dropdown($form, 'upload');

  $form->add_element( type => 'Text', name => 'text', label => 'Paste file' );
  $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $form->add_element( type => 'URL',  name => 'url',  label => 'or provide file URL', size => 30 );

  $html .= $form->render;
  
  return $html;
}

1;
