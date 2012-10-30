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
  my $max_upload_size = abs($sd->CGI_POST_MAX / 1048576).'MB'; # Should default to 5.0MB :)
  my %urls            = ( 'upload' => $hub->url({'type' => 'UserData', 'action' => 'UploadFile'}), 'remote' => $hub->url({'type' => 'UserData', 'action' => 'AttachRemote'}) );
  my $form            = $self->modal_form('select', $urls{'upload'}, {'label'=>'Upload'});

  $form->add_hidden({'name' => $_, 'value' => $urls{$_}}) for keys %urls;

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

  $self->add_file_format_dropdown($form, '', 1);

  my $upload_fieldset = $form->add_fieldset({'class' => '_stt_upload'});
  my $remote_fieldset = $form->add_fieldset({'class' => '_stt_remote'});

  my $actions = [
    {'caption' => "Upload data (max $max_upload_size)",    'value' => 'upload', 'class' => '_stt__upload1 _stt _action _action_upload', 'checked' => 1},
    {'caption' => 'Attach via URL', 'value' => 'remote', 'class' => '_stt__remote1 _stt _action _action_remote'},
  ];

  $upload_fieldset->add_field({ 'type' => 'Radiolist', 'name' => 'action', 'label' => 'Type', 'values' => $actions });

  $upload_fieldset->add_field({ 'field_class' => 'hidden _stt_upload1', 'type' => 'Text', 'name' => 'text', 'label' => 'Paste data' });
  $upload_fieldset->add_field({ 'field_class' => 'hidden _stt_upload1', 'type' => 'File', 'name' => 'file', 'label' => 'Or choose file' });
  $upload_fieldset->add_field({
    'type'        => 'URL',
    'name'        => 'url',
    'label'       => '<span class="_stt_remote1">P</span><span class="_stt_upload1">Or p</span>rovide file URL',
    'size'        => 30
  });

  $remote_fieldset->add_field({ 'type' => 'URL', 'name' => 'url_2', 'label' => 'Provide file URL', 'size' => 30 });

  $form->add_fieldset; #an extra fieldset for the submit button that gets automatically added

  return sprintf '<input type="hidden" class="panel_type" value="UserData" /><h2>Add a custom track</h2>%s', $form->render;
}

1;
