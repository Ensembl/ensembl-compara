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
  my @values = map {uc($_)} @{$export_info{lc($hub->action)}};
  unshift @values, '--- CHOOSE FORMAT ---';
  $fieldset->add_field([
    {
      'type'    => 'DropDown',
      'name'    => 'format',
      'label'   => 'File format',
      'values'  => \@values,
      'select'  => 'select',
    },
    {
      'type'    => 'String',
      'name'    => 'name',
      'label'   => 'File name (optional)',
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

  ## TODO Needs to be configurable with JavaScript!
  my $format    = 'fasta';
  my $fields    = $fields_by_format->{$format};
  warn "!!! FORMAT NOT CONFIGURED!" unless $fields;
  my $legend    = $fields->{'shown'} ? 'Settings' : '';
  my $settings_fieldset  = $form->add_fieldset($legend);

  ## Add custom fields for this data type and format
  while (my($key, $field_array) = each (%$fields)) {
    foreach (@$field_array) {
      my $field_info = $settings->{$_};
      $field_info->{'name'} = $_;
      $field_info->{'value'}  = $field_info->{'defaults'}{$format} if $field_info->{'defaults'}{$format};
      delete $field_info->{'defaults'};
      if ($key eq 'hidden') {
        $settings_fieldset->add_hidden($field_info);
      }
      else {
        $settings_fieldset->add_field($field_info);
      }
    }
  }

  $settings_fieldset->add_button({
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Export',
  });

  return $form;
}

1;
