=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::DataExport;

### Parent module for new data export interface

### STATUS: Under Development

### DESCRIPTION: Contains base functionality needed by all
### DataExport input forms

use strict;

use base qw(EnsEMBL::Web::Component);

sub create_form {
### Builds the input form used by DataExport
### Note that the form consists of a generic section (file name, format)
### plus multiple format-specific option fieldsets which are hidden by 
### JavaScript until the user chooses a format in the top section
### @param Hashref - form element configuration options
### @param Hashref - additional form settings for specific output formats
### @return EnsEMBL::Web::Form
  my ($self, $settings, $fields_by_format, $tutorial) = @_;
  my $hub  = $self->hub;

  my $format_label = {
    'RTF'   => 'RTF (Word-compatible)',
    'FASTA' => 'FASTA',
  };

  my $form = $self->new_form({'id' => 'export', 'action' => $hub->url({'action' => 'Output',  'function' => '', '__clear' => 1}), 'method' => 'post'});

  ## Generic fields
  my $fieldset = $form->add_fieldset;

  my $filename = $hub->param('filename') || $self->default_file_name;
  $filename =~ s/\.[\w|\.]+//;

  ## Deal with optgroups
  my (@format_info, %ok_formats);
  if (ref($fields_by_format) eq 'ARRAY') {
    foreach (@$fields_by_format) {
      while (my($group,$formats) = each (%$_)) {
        push @format_info, $self->_munge_format_info($formats, $group);
        while (my($f,$h) = each (%$formats)) {
          $ok_formats{$f} = $h;
        }
      }
    }
  }
  else {
    @format_info = $self->_munge_format_info($fields_by_format);
    while (my($k,$v) = each (%$fields_by_format)) {
      $ok_formats{$k} = $v;
    }
  }

  my $formats = [
      {'caption' => '-- Choose Format --'},
      @format_info
    ];
  ## Don't update this field from params, as there's no back 
  ## button for compressed formats!
  my $compress = [
      {'caption' => 'Uncompressed', 'value' => '', 'checked' => 1},
      {'caption' => 'Gzip', 'value' => 'gz'},
      #{'caption' => 'Zip', 'value' => 'zip'},
  ];
  $fieldset->add_field([
    {
      'type'    => 'String',
      'name'    => 'name',
      'label'   => 'File name',
      'value'   => $filename,
    },
  ]);
  if (scalar(@format_info) > 1) {
    $fieldset->add_field([
      {
        'type'    => 'DropDown',
        'name'    => 'format',
        'label'   => 'File format',
        'values'  => $formats,
        'select'  => 'select',
        'class'   => '_stt _export_formats',
      },
    ]);
  }
  else {
    my $info = $format_info[0];
    $fieldset->add_field([
      {
        'type'    => 'NoEdit',
        'label'   => 'File format',
        'value'   => $info->{'caption'},
      },
    ]);
    $fieldset->add_hidden([
      {
        'name'    => 'format',
        'value'   => $info->{'value'},
      },
    ]);
  }
  $fieldset->add_field([
    {
      'type'    => 'Radiolist',
      'name'    => 'compression',
      'label'   => 'Output',
      'values'  => $compress,
      'notes'   => 'Select "uncompressed" to get a preview of your file',
    },
  ]);
  ## Hidden fields needed to fetch and process data
  $fieldset->add_hidden([
    {
      'name'    => 'data_type',
      'value'   => $hub->param('data_type'),
    },
    {
      'name'    => 'component',
      'value'   => $hub->param('component'),
    },
    {
      'name'    => 'export_action',
      'value'   => $hub->action,
    },
  ]);
  ## Miscellaneous parameters from settings
  foreach (@{$settings->{'Hidden'}||[]}) {
    $fieldset->add_hidden([
      {
        'name'    => $_,
        'value'   => $hub->param($_),
      },
    ]);
  }
  $fieldset->add_hidden([{ name => 'adorn', value => 'both' }]);

  ## Don't forget the core params!
  my @core_params = keys %{$hub->core_object('parameters')};
  foreach (@core_params) {
    $fieldset->add_hidden([
      {
        'name'    => $_,
        'value'   => $hub->param($_),
      },
    ]);
  }

  ## Create all options forms, then show only one using jQuery
  while (my($format, $fields) = each (%ok_formats)) {
    my $legend = scalar(@$fields) ? 'Settings' : '';
    my $settings_fieldset  = $form->add_fieldset({'class' => '_stt_'.$format, 'legend' => $legend});

    ## Add custom fields for this data type and format
    foreach my $name (@$fields) {
      ## IMPORTANT - use hashes here, not hashrefs, as Form code does weird stuff 
      ## in background that alters the contents of $settings!
      my %field_info = %{$settings->{$name}||{}};
      next unless keys %field_info;
      ## Reset field name to include format, so we have unique field names
      $name .= '_'.$format;
      $field_info{'name'} = $name;
      my @values = @{$field_info{'values'}||[]};
      ## Deal with multiple values, which have to be passed
      ## to Form::Fieldset as an arrayref
      my $params;
      if (scalar @values > 1) { ## Dropdown
        if ($field_info{'type'} eq 'Hidden') {
          $params = [];
          foreach my $v (@values) {
            my %info = %field_info;
            $info{'value'} = $v;
            push @$params, \%info;
          }
        }
        else {
          $params = \%field_info;
        }
      }
      else {
        if ($field_info{'type'} =~ /Checkbox|CheckBox/) {
          $field_info{'selected'} = 1 if $field_info{'value'} eq 'on';
          $field_info{'value'} = 'on' if $field_info{'value'} eq 'off'; ## stupid checkboxes are stupid
        }
        $params = \%field_info;
      }
      ## Add to form
      if ($field_info{'type'} eq 'Hidden') {
        $settings_fieldset->add_hidden($params);
      }
      else { 
        $settings_fieldset->add_field($params);
      }
    }

    ## Doesn't matter that each fieldset has a submit button, as we only ever
    ## display one of them - and putting it here forces user to choose format!
    $settings_fieldset->add_button({
      'type'    => 'Submit',
      'name'    => 'submit',
      'value'   => 'Download',
    });
  }

  ## Add images fieldset
  if ($tutorial) {
    my $tutorial_fieldset = $form->add_fieldset;
    my $html = '<p><b>Guide to file formats</b></p><div class="_export_formats export-formats">';
    foreach my $format (sort {lc($a) cmp lc($b)} keys %ok_formats) {
      $html .= $self->show_preview($format);
    }
    $html .= '</div>';
    $tutorial_fieldset->add_notes($html);
  }

  return $self->dom->create_element('div', {
    'id'        => 'DataExport',
    'class'     => 'js_panel',
    'children'  => [ {'node_name' => 'input', 'class' => 'subpanel_type', 'value' => 'DataExport', 'type' => 'hidden' }, $form ]
  });
}

sub default_file_name { 
### Generic name - ideally should be overridden in children
  my $self = shift;
  return $self->hub->species_defs->ENSEMBL_SITETYPE.'_data_export';
}

sub show_preview {
  my ($self, $format) = @_;
  my $img = lc($format);
  $img .= '_align' if (lc($format) eq 'fasta' && $self->hub->param('align'));
  
  my $html = sprintf('<div><p>%s</p><p><img src="/img/help/export/%s_preview.png" /></p></div>', $format, $img);
  return $html;
}

## Only needs to be set for a format if we want to insert extra text into the dropdown
our $format_label = {
  'RTF'   => 'RTF (Word-compatible)',
};


sub _munge_format_info {
  my ($self, $hashref, $optgroup) = @_;
  my @munged_info;

  foreach (sort {lc($a) cmp lc($b)} keys %$hashref) {
    my $info = {'value' => $_,
                'caption' => $format_label->{$_} || $_,
                'class' => "_stt__$_ _action_$_",
                };
    $info->{'group'} = $optgroup if $optgroup;
    $info->{'selected'} = 'selected' if $self->hub->param('format') eq $_;
    push @munged_info, $info;
  }
  return @munged_info;
}

1;
