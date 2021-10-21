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

package EnsEMBL::Web::Component::DataExport::Protein;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::DataExport);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  ### Options for protein sequence output
  my $self  = shift;
  my $hub   = $self->hub;

  my $checklist = [];
  foreach (EnsEMBL::Web::Constants::FASTA_OPTIONS) {
    $_->{'checked'} = 'on' if $_->{'value'} eq 'peptide';
    push @$checklist, $_;
  }

  ## Get user's current settings
  my $view_config  = $self->view_config;

  my $settings = $view_config->form_fields;

  $settings->{'extra'} = {
          'type'      => 'Checklist',
          'label'     => 'Sequences to export',
          'values'    => $checklist,
          'selectall' => 'off',
  };

  ## Options per format
  my @field_order = $view_config->field_order;

  my $fields_by_format = {
                          'RTF'   => [@field_order],
                          'FASTA' => ['extra'],
  };

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

sub default_file_name {
  my $self = shift;
  my $name = $self->hub->species;
  my $data_object = $self->hub->param('t') ? $self->hub->core_object('transcript') : undef;
  if ($data_object) {
    $name .= '_';
    my $versioned_stable_id = $data_object->translation_object()->stable_id_version || $data_object->translation_object()->stable_id;
    # Replace '.' with '_' to avoid file extention clashes 
    $versioned_stable_id =~ s/\./_/g; 
    $name .= $versioned_stable_id;
  }
  $name .= '_sequence';
  return $name;
}

1;
