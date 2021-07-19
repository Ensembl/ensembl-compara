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

package EnsEMBL::Web::Configuration::DataExport;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Configuration);

sub caption { 
  my $self = shift;
  return 'Export '.$self->hub->action; 
}

sub populate_tree {
  my $self  = shift;

  ## Input nodes:

  ## Text sequence
  my @input_nodes = qw(ExonSeq FlankingSeq GeneSeq Protein Transcript TranscriptComparison);
  foreach (@input_nodes) {
    $self->create_node($_, "Sequence Input", [lc($_), 'EnsEMBL::Web::Component::DataExport::'.$_]);
  }

  ## Compara alignments and trees
  $self->create_node('Alignments', 'Alignments', ['alignments', 'EnsEMBL::Web::Component::DataExport::Alignments']);
  $self->create_node('TextAlignments', 'Alignments', ['text_alignments', 'EnsEMBL::Web::Component::DataExport::TextAlignments']);
  $self->create_node('Homologs', 'Alignments', ['alignments', 'EnsEMBL::Web::Component::DataExport::Homologs']);
  $self->create_node('Orthologs', 'Orthologues', ['orthologues', 'EnsEMBL::Web::Component::DataExport::Orthologs']);
  $self->create_node('Paralogs', 'Paralogues', ['paralogues', 'EnsEMBL::Web::Component::DataExport::Paralogs']);
  $self->create_node('Family', 'Ensembl protein Family', ['family', 'EnsEMBL::Web::Component::DataExport::Family']);
  $self->create_node('GeneTree', 'Gene Tree', ['genetree', 'EnsEMBL::Web::Component::DataExport::GeneTree']);
  $self->create_node('SpeciesTree', 'Species Tree', ['species_tree', 'EnsEMBL::Web::Component::DataExport::SpeciesTree']);

  ## Preview
  $self->create_node('Results', 'Alignment', ['results', 'EnsEMBL::Web::Component::DataExport::Results']);

  ## External alignments
  $self->create_node('Emboss', 'Alignment', ['emboss', 'EnsEMBL::Web::Component::DataExport::Emboss']);

  ## Output nodes
  $self->create_node('Output',  '', [], { 'command' => 'EnsEMBL::Web::Command::DataExport::Output'});
  $self->create_node('Error', 'Output Error', ['error', 'EnsEMBL::Web::Component::DataExport::Error']);
}

1;
