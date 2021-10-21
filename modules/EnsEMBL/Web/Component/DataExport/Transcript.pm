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

package EnsEMBL::Web::Component::DataExport::Transcript;

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
  ### Options for gene sequence output
  my $self  = shift;
  my $hub   = $self->hub;

  ## Get user's current settings
  my $view_config  = $self->view_config;
  my $settings = $view_config->form_fields;

  ## Configure sequence options - check if the transcript 
  ## has translations and/or UTRs
  my @fasta_info = $self->configure_fasta; 

  my $options = {};
  my ($component, $error) = $self->object->create_component;
  my $t = $component->get_export_data;
  $options->{'utr3'}    = $t->three_prime_utr ? 1 : 0;
  $options->{'utr5'}    = $t->five_prime_utr ? 1 : 0;

  my $checklist = [];
  foreach (@fasta_info) {
    $_->{'checked'} = 1;
    push @$checklist, $_ unless (exists $options->{$_->{'value'}} && $options->{$_->{'value'}} == 0); 
  }

  $settings->{'extra'} = {
                          'type'      => 'Checklist',
                          'label'     => 'Included sequences',
                          'values'    => $checklist,
                          'selectall' => 'on',
  };

  $settings->{'variants_as_n'} = {
    type  => 'CheckBox',
    label => 'Replace ambiguous bases with N',
    name  => 'variants_as_n',
    value => 'on',
    no_user => 1,
  };

  ## Options per format
  my $fields_by_format = $self->configure_fields($view_config);

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

sub configure_fasta {
## Default is to return everything
  my $self = shift;
  my @fasta = EnsEMBL::Web::Constants::FASTA_OPTIONS;
  return @fasta;
}

sub configure_fields {
  my ($self, $view_config) = @_;
  my @field_order = $view_config->field_order;

  my @extra_export_fields = qw(variants_as_n);
  return {
          'RTF'   => [@field_order,@extra_export_fields],
          'FASTA' => ['extra'],
  };
}

sub default_file_name {
  my $self = shift;
  my $name = $self->hub->species;
  my $data_object = $self->hub->param('t') ? $self->hub->core_object('transcript') : undef;
  if ($data_object) {
    $name .= '_';
    my $versioned_stable_id = $data_object->stable_id_version || $data_object->stable_id;
    # Replace '.' with '_' to avoid file extention clashes 
    $versioned_stable_id =~ s/\./_/g; 
    $name .= $versioned_stable_id;
  }
  $name .= '_sequence';
  return $name;
}

1;
