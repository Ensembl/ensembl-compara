=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use strict;

use base qw( EnsEMBL::Web::Component);

sub create_form {
  my ($self, $settings, $fields_by_format) = @_;
  my $hub  = $self->hub;

  my $form_url  = sprintf('/%s/DataExport/Output', $hub->species);
  my $form      = $self->new_form({'id' => 'export', 'action' => $form_url, 'method' => 'post'});

  my $fieldset  = $form->add_fieldset; 
  my %export_info = EnsEMBL::Web::Constants::EXPORT_TYPES;
  my $formats = [
      {'caption' => '-- Choose Format --', 'value' => ''},
      map { 'value' => uc($_), 'caption' => uc($_), 'class' => "_stt__$_ _action_$_"},  @{$export_info{lc($hub->action)}}
    ];
  my $compress = [
      {'caption' => 'Uncompressed', 'value' => '', 'checked' => 1},
      {'caption' => 'Gzip', 'value' => 'gz'},
      #{'caption' => 'Zip', 'value' => 'zip'},
  ];
  $fieldset->add_field([
    {
      'type'    => 'DropDown',
      'name'    => 'format',
      'label'   => 'File format',
      'values'  => $formats,
      'select'  => 'select',
      'class'   => '_stt _action',
    },
    {
      'type'    => 'String',
      'name'    => 'name',
      'label'   => 'File name (optional)',
    },
    {
      'type'    => 'Radiolist',
      'name'    => 'compression',
      'label'   => 'Output',
      'values'  => $compress,
    },
  ]);
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
      'name'    => 'r',
      'value'   => $hub->param('r'),
    },
    {
      'name'    => 'g',
      'value'   => $hub->param('g'),
    },
  ]);

  ## Create all options forms, then show only one using jQuery
  while (my($format, $fields) = each (%$fields_by_format)) {
    my $legend    = $fields->{'shown'} ? 'Settings' : '';
    my $settings_fieldset  = $form->add_fieldset({'class' => '_stt_'.$format, 'legend' => $legend});

    ## Add custom fields for this data type and format
    while (my($key, $field_array) = each (%$fields)) {
      my $i = 0;
      foreach (@$field_array) {
        ## IMPORTANT - use hashes here, not hashrefs, as Form code does weird stuff 
        ## in background that alters the contents of $settings!
        my %field_info = %{$settings->{$_}};
        $field_info{'name'} = $_;
        if ($key eq 'hidden') {
          $settings_fieldset->add_hidden(\%field_info);
        }
        else {
          $settings_fieldset->add_field(\%field_info);
        }
        $i++;
      }
    }
    ## Doesn't matter that each fieldset has a submit button, as we only
    ## ever display one of them - and it forces user to choose format!
    $settings_fieldset->add_button({
      'type'    => 'Submit',
      'name'    => 'submit',
      'value'   => 'Export',
    });
  }


  return $form;
}

1;
