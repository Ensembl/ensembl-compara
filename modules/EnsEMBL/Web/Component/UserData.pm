=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::UserData;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component);

use strict;

sub get_assemblies {
  ### Tries to identify coordinate system from file contents
  ### If on chromosomal coords and species has multiple assemblies,
  ### return assembly info
  
  my ($self, $species) = @_;
  my @assemblies = split(',', $self->hub->species_defs->get_config($species, 'CURRENT_ASSEMBLIES'));
  return \@assemblies;
}

sub add_file_format_dropdown {
  my ($self, $form, $limit, $js_enabled) = @_;

  my $sd              = $self->hub->species_defs;
  my @remote_formats  = $limit && $limit eq 'upload' ? () : @{$sd->multi_val('REMOTE_FILE_FORMATS')||[]};
  my @upload_formats  = $limit && $limit eq 'remote' ? () : @{$sd->multi_val('UPLOAD_FILE_FORMATS')||[]};
  my $format_info     = $sd->multi_val('DATA_FORMAT_INFO');
  my %format_type     = (map({$_ => 'remote'} @remote_formats), map({$_ => 'upload'} @upload_formats));
  ## Override defaults for trackhub, which is a special case
  $format_type{'trackhub'} = 'trackhub';

  if (scalar @remote_formats || scalar @upload_formats) {
    my $values = [
      {'caption' => '-- Choose --', 'value' => ''},
      map { 'value' => uc($_), 'caption' => $format_info->{$_}{'label'}, $js_enabled ? ('class' => "_stt__$format_type{$_} _action_$format_type{$_}") : () }, sort (@remote_formats, @upload_formats)
    ];
    $form->add_field({
      'type'    => 'dropdown',
      'name'    => 'format',
      'label'   => 'Data format',
      'values'  => $values,
      'notes'   => '<a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a>',
      $js_enabled ? ( 'class' => '_stt _action' ) : ()
    });
  }
}

sub add_auto_format_dropdown {
  my ($self, $form) = @_;

  my $format_info     = EnsEMBL::Web::Constants::USERDATA_FORMATS; 
  $format_info        = $self->add_extra_formats($format_info); 
  my $sorted_values   = [{'caption' => '-- Choose --', 'value' => ''}];
  my @format_values;

  while (my ($format, $info) = each (%$format_info)) {
    my $class;
    if ($info->{'limit'}) {
      my $limit = $info->{'limit'};
      $class = "_format_$limit";
    }
    push @format_values, {'value' => uc($format), 'caption' => $info->{'label'}, 'class' => $class ? $class : ''};
  }

  push @$sorted_values, sort {$a->{'value'} cmp $b->{'value'}} @format_values;

  $form->add_field({
      'type'    => 'dropdown',
      'name'    => 'format',
      'label'   => 'Data format',
      'values'  => $sorted_values,
      'required' => 1,
      'class'   => 'hide',
      'notes'   => '<a href="/info/website/upload/index.html" class="popup">Help on supported formats, display types, etc</a>',
    });
}

sub add_extra_formats {
  ## Stub - used by tools
  my ($self, $format_info) = @_;
  return $format_info;
}

sub trackhub_search {
  my $self            = shift;
  my $hub             = $self->hub;
  return sprintf '<a href="%s" class="modal_link inline-button find" style="inline-block" rel="modal_user_data">Search for public track hubs</a></p>', $hub->url({'action' => 'TrackHubSearch'});
}

sub userdata_form {
  my $self  = shift;
  my $hub   = $self->hub;

  my $sd              = $hub->species_defs;
  my $sitename        = $sd->ENSEMBL_SITETYPE;
  my $current_species = $hub->data_species;
  my $max_upload_size = abs($sd->CGI_POST_MAX / 1048576).'MB'; # Should default to 5.0MB :)

  my $message         = qq(<p>
Please note that track hubs and indexed files (BAM, BigBed, etc) do not work with certain
cloud services, including <b>Google Drive</b> and <b>Dropbox</b>. Please see our 
<a href="/info/website/trackhubs/trackhub_support.html">support page</a> for more information.
</p>);


  my $form            = $self->modal_form('select', $hub->url({'type' => 'UserData', 'action' => 'AddFile'}), {
    'skip_validation'   => 1, # default JS validation is skipped as this form goes through a customised validation
    'class'             => 'check bgcolour',
    'no_button'         => 1
  });

  my $fieldset        = $form->add_fieldset({'no_required_notes' => 1});

  $fieldset->add_field({'type' => 'String', 'name' => 'name', 'label' => 'Name for this data (optional)'});

  # Species dropdown list
  $fieldset->add_field({
    'label'         => 'Species',
    'elements'      => [{
      'type'          => 'noedit',
      'value'         => $sd->species_label($current_species),
      'no_input'      => 1,
      'is_html'       => 1,
    },
    {
      'type'          => 'noedit',
      'value'         => 'Assembly: '. $sd->get_config($current_species, 'ASSEMBLY_VERSION'),
      'no_input'      => 1,
      'is_html'       => 1
    }]
  });

  $fieldset->add_hidden({'name' => 'species', 'value' => $current_species});

  if ($hub->param('tool')) {
    $fieldset->add_hidden({'name' => 'tool', 'value' => $hub->param('tool')});
  }

  $fieldset->add_field({
    'label'         => 'Data',
    'field_class'   => '_userdata_add',
    'elements'      => [{
      'type'          => 'Text',
      'value'         => 'Paste in data or provide a file URL',
      'name'          => 'text',
      'class'         => 'inactive'
    }, {
      'type'          => 'noedit',
      'value'         => "Or upload file (max $max_upload_size)",
      'no_input'      => 1,
      'element_class' => 'inline-label'
    }, {
      'type'          => 'File',
      'name'          => 'file',
    }]
  });

  $self->add_auto_format_dropdown($form);

  $fieldset->add_button({
    'type'          => 'Submit',
    'name'          => 'submit_button',
    'value'         => 'Add data'
  });

  return sprintf '<input type="hidden" class="subpanel_type" value="UserData" /><h2>Add a custom track</h2>%s%s', $message, $form->render;
}

1;

