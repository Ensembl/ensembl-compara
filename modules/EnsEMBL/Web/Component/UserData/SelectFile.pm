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
  my $self            = shift;
  my $hub             = $self->hub;
  my $sd              = $hub->species_defs;
  my $sitename        = $sd->ENSEMBL_SITETYPE;
  my $current_species = $hub->data_species;
  my $max_upload_size = sprintf("%.1f", $sd->CGI_POST_MAX / 1048576).'MB'; # Should default to 5.0MB :)
  my $form            = $self->modal_form('select', $hub->species_path($current_species) . "/UserData/UploadFile", {'label'=>'Upload'});

  if (!$hub->param('filter_module')) { ## No errors
    $form->add_notes({'id' => 'upload_notes', 'heading' => 'IMPORTANT NOTE', 'text' => qq{
      <p>We are only able to store single-species datasets, containing data on $sitename coordinate systems. There is also a $max_upload_size limit on data uploads. 
      If your data does not conform to these guidelines, you can still <a href="/$current_species/UserData/AttachURL" class="modal_link">attach it to $sitename</a> without uploading.</p>
      <p><a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a></p>
    }});
  }

  $form->add_field({'type' => 'String', 'name' => 'name', 'label' => 'Name for this upload (optional)'});

  # Create a data structure for species, with display labels and their current assemblies
  my @species = sort {$a->{'caption'} cmp $b->{'caption'}} map({'value' => $_, 'caption' => $sd->species_label($_, 1), 'assembly' => $sd->get_config($_, 'ASSEMBLY_NAME')}, $sd->valid_species);

  # Create HTML for showing/hiding assembly names to work with JS
  my $assembly_names = join '', map { sprintf '<span class="_stt_%s%s">%s</span>', $_->{'value'}, $_->{'value'} eq $current_species ? '' : ' hidden', delete $_->{'assembly'} } @species;

  $form->add_field({
      'type'        => 'dropdown',
      'name'        => 'species',
      'label'       => 'Species',
      'values'      => \@species,
      'value'       => $current_species,
      'class'       => '_stt'
  });

  ## Are mappings available?
  ## FIXME - reinstate auto-mapping option when we have a solution!
  ## TODO - once fixed, the assembly name toggling (wrt species selected) will need redoing - hr5
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
      'type'        => 'DropDown',
      'name'        => 'assembly',
      'label'       => "Assembly",
      'values'      => \@values,
      'value'       => $current_assembly,
      'select'      => 'select',
    );
    $form->add_element(
      'type'        => 'Information',
      'value'       => 'Please note: if your data is not on the current assembly, the coordinates will be converted',
    );
  }
  else {
    $form->add_field({
      'type'        => 'noedit',
      'label'       => 'Assembly',
      'name'        => 'assembly_name',
      'value'       => $assembly_names,
      'no_input'    => 1,
      'is_html'     => 1
    });
  }

  $self->add_file_format_dropdown($form);

  $form->add_field({ 'field_class' => 'hidden _stt_upload', 'type' => 'Text', 'name' => 'text', 'label' => 'Paste data' });
  $form->add_field({ 'field_class' => 'hidden _stt_upload', 'type' => 'File', 'name' => 'file', 'label' => 'Or upload file' });

  ## Only one of these will be shown, depending on JS action
  $form->add_field({ 'field_class' => 'hidden _stt_remote', 'type' => 'URL',  'name' => 'url',  'label' => 'Provide file URL', 'size' => 30 });
  $form->add_field({ 'field_class' => 'hidden _stt_upload', 'type' => 'URL',  'name' => 'url',  'label' => 'Or provide file URL', 'size' => 30 });

  return $form->render;
}

1;
