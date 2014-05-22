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

package EnsEMBL::Web::Component::DataExport::GeneSeq;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::DataExport::Sequence);

sub content {
  ### Options for gene sequence output
  my $self  = shift;
  my $hub   = $self->hub;

  ## Configure sequence options - check if the gene's transcripts 
  ## have translations and/or UTRs
  my $options = { peptide => 0, utr3 => 0, utr5 => 0 };
  my ($component, $error) = $self->object->create_component;
  foreach ($component->get_export_data) {
    $options->{'peptide'} = 1 if $_->translation;
    $options->{'utr3'}    = 1 if $_->three_prime_utr;
    $options->{'utr5'}    = 1 if $_->five_prime_utr;
    last if $options->{'peptide'} && $options->{'utr3'} && $options->{'utr5'};    
  }

  my $checklist = [];
  foreach (EnsEMBL::Web::Constants::FASTA_OPTIONS) {
    push @$checklist, $_ unless (exists $options->{$_->{'value'}} && $options->{$_->{'value'}} == 0); 
  }

  ## Get user's current settings
  my $viewconfig  = $hub->get_viewconfig($hub->param('component'), $hub->param('data_type'));

  my $settings = {
        'gene' => {
            'label'   => 'Gene Sequence', 
            'type'    => 'Checkbox', 
            'value'   => 'on',
            'checked' => 1, 
        },
        'flank5_display' => {
            'label'     => "5' Flanking sequence (upstream)",  
            'type'      => 'NonNegInt',  
        },
        'flank3_display' => { 
            'label'     => "3' Flanking sequence (downstream)", 
            'type'      => 'NonNegInt',  
        },
        'extra' => {
          'type'      => 'Checklist',
          'label'     => 'Additional sequences',
          'values'    => $checklist,
          'selectall' => 'off',
        },
        'snp_display' => {
            'label'   => 'Include variations',
            'type'    => 'Checkbox',
            'value'   => 'on',
            'checked' => $viewconfig->get('snp_display') eq 'off' ? 0 : 1,
        },
  };

  ## Options per format
  my $fields_by_format = {
    'RTF' => [
                ['flank5_display',  $viewconfig->get('flank5_display')], 
                ['flank3_display',  $viewconfig->get('flank3_display')],
                ['snp_display'],
              ],  
    'FASTA' => [
                ['gene'],
                ['flank5_display', 0],
                ['flank3_display', 0],
                ['extra'],
               ], 
  };

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format);

  return $form->render;
}

sub default_file_name {
  my $self = shift;
  my $name = $self->hub->species;
  my $data_object = $self->hub->param('g') ? $self->hub->core_object('gene') : undef;
  if ($data_object) {
    $name .= '_';
    my $stable_id = $data_object->stable_id;
    my ($disp_id) = $data_object->display_xref;
    $name .= $disp_id || $stable_id;
  }
  $name .= '_sequence';
  return $name;
}

1;
