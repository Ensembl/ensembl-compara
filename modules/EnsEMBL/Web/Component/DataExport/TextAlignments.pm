=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::DataExport::TextAlignments;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::DataExport::Alignments);

sub content {
  ### Options for gene sequence output
  my $self  = shift;
  my $hub   = $self->hub;

  ## Get user's current settings
  my $view_config  = $self->viewconfig;

  my $settings = $view_config->form_fields({'no_snp_link' => 1});

  ## Pass species selection to output
  my @species_options;

  my $alignments_session_data = $hub->session ? $hub->session->get_record_data({'type' => 'view_config', 'code' => 'alignments_selector'}) : {};
  %{$self->{'viewconfig'}{$hub->param('data_type')}->{_user_settings}} = (%{$self->{'viewconfig'}{$hub->param('data_type')}->{_user_settings}||{}}, %{$alignments_session_data||{}});
  my $user_settings = $self->{'viewconfig'}{$hub->param('data_type')}->{_user_settings};
  my $align = $hub->param('align') || $user_settings->{'align'};
  my $align_type = $hub->param('align_type') || $user_settings->{'align_type'};

  $settings->{'Hidden'} = ['align', 'align_type'];

  ## Options per format
  my @field_order = $view_config->field_order;
  my $fields_by_format = {'RTF' => [@field_order]};

  ## Add formats output by BioPerl
  foreach ($self->alignment_formats) {
    $fields_by_format->{$_} = [];
  }

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

1;
