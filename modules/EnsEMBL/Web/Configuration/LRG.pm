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

package EnsEMBL::Web::Configuration::LRG;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = $self->object ? $self->object->default_action : 'Genome';
}

sub has_tabs { return 1; }

sub short_caption {
  my $self = shift;
  return 'LRG-based displays';
}

sub caption {
  my $self = shift;
  my $caption;
  
  if ($self->hub->param('lrg')) {
    $caption = 'LRG: ' . $self->hub->param('lrg'); 
  } else {
    $caption = 'LRGs';
  }
  
  return $caption;
}

sub counts {
  my $self = shift;
  my $hub = $self->hub;
  my $obj = $self->builder->api_object('Gene');

  return {} unless $obj;

  my $key = sprintf '::COUNTS::GENE::%s::%s::%s::', $hub->species, $hub->param('db'), $hub->param('lrg');
  my $counts = $hub->cache ? $hub->cache->get($key) : undef;

  if (!$counts) {
    $counts = {
      transcripts => scalar @{$self->builder->api_object('Transcript')},
      genes       => 1,
    };

    $hub->cache->set($key, $counts, undef, 'COUNTS') if $hub->cache;
  }
 
  return $counts;
}

sub populate_tree {
  my $self = shift;
  
  $self->create_node('Genome', 'All LRGs',
    [qw(
      karyotype EnsEMBL::Web::Component::LRG::Genome 
    )]
  );

  $self->create_node('Summary', 'LRG summary',
    [qw(
      transcripts EnsEMBL::Web::Component::LRG::TranscriptsImage  
    )],
    { 'availability' => 'lrg' }
  );

  my $seq_menu = $self->create_submenu('Sequence', 'Sequence');
  
  $seq_menu->append($self->create_node('Sequence_DNA', 'Sequence',
    [qw( exons EnsEMBL::Web::Component::LRG::LRGSeq )],
    { 'availability' => 'lrg' }
  ));

  $seq_menu->append($self->create_node('Differences', 'Reference comparison',
    [qw(
      exons EnsEMBL::Web::Component::LRG::LRGDiff
      align EnsEMBL::Web::Component::LRG::LRGAlign)],
    { 'availability' => 'lrg' }
  ));
	
  $seq_menu->append($self->create_node('Exons', 'Exons',
    [qw( exons EnsEMBL::Web::Component::LRG::ExonsSpreadsheet )],
    { 'availability' => 'lrg', 'concise' => 'Exons' }
  ));
  
  $seq_menu->append($self->create_node('Sequence_cDNA', 'cDNA',
    [qw( sequence EnsEMBL::Web::Component::LRG::TranscriptSeq )],
    { 'availability' => 'lrg', 'concise' => 'cDNA sequence' }
  ));
  
  $seq_menu->append($self->create_node('Sequence_Protein', 'Protein',
    [qw( sequence EnsEMBL::Web::Component::LRG::ProteinSeq )],
    { 'availability' => 'lrg', 'concise' => 'Protein sequence' }
  ));

  $self->create_node('ProteinSummary', 'Protein summary',
    [qw(
      image      EnsEMBL::Web::Component::LRG::TranslationImage
    )],
    { 'availability' => 'lrg', 'concise' => 'Protein summary' }
  );

  $self->create_node('Phenotype',  'Phenotype',
    [qw(
      phenotype EnsEMBL::Web::Component::LRG::GenePhenotype
      variation EnsEMBL::Web::Component::LRG::LRGPhenotypeVariation
      orthologue EnsEMBL::Web::Component::LRG::GenePhenotypeOrthologue
    )],
    { 'availability' => 1 }
   );
 
  my $var_menu = $self->create_submenu('Variation', 'Genetic Variation');

  $var_menu->append($self->create_node('Variation_LRG/Table', 'Variation Table',
    [qw( snptable EnsEMBL::Web::Component::LRG::VariationTable )],
    { 'availability' => 'lrg' }
  ));

  $var_menu->append($self->create_node('StructuralVariation_LRG', 'Structural variation',
    [qw(
      svimage EnsEMBL::Web::Component::LRG::SVImage
      svtable EnsEMBL::Web::Component::LRG::SVTable
    )],
    { 'availability' => 'lrg has_structural_variation core' }
  ));


  $self->create_subnode('Output', 'Export LRG Data',
    [qw( export EnsEMBL::Web::Component::Export::Output )],
    { 'availability' => 'lrg', 'no_menu_entry' => 1 }
  );
}

1;
