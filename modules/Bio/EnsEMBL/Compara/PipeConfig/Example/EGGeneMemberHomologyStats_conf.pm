=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EGGeneMemberHomologyStats_conf

=head1 SYNOPSIS

    init_pipeline.pl 
      Bio::EnsEMBL::Compara::PipeConfig::EGGeneMemberHomologyStats_conf 
      -curr_rel_db mysql://ensrw:XXX\@server/merged_compara_db 
      -collection collection_name

=head1 DESCRIPTION

    A simple pipeline to populate the gene_member_hom_stats table
    for a single collection.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::EGGeneMemberHomologyStats_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::GeneMemberHomologyStats_conf');

sub pipeline_wide_parameters {
 my ($self) = @_;
 
 return {
   %{$self->SUPER::pipeline_wide_parameters},
   'db_conn'    => $self->o('curr_rel_db'),
   'collection' => $self->o('collection'),
 };
}

sub pipeline_analyses {
  my ($self) = @_;
  
  my $init_module = {
    -logic_name        => 'initialise_pipeline',
    -module            => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
    -input_ids         => [ {} ],
    -flow_into         => ['find_collection_species_set_id'],
    -meadow_type       => 'LOCAL',
  };
  
  my $pipeline_analyses = $self->SUPER::pipeline_analyses;
  
  foreach my $analysis (@$pipeline_analyses) {
    if ($analysis->{-logic_name} eq 'stats_gene_trees') {
      foreach my $sql (@{$analysis->{-parameters}{sql}}) {
        $sql =~ s/(clusterset_id = )"#collection#"/$1"default"/;
      }
    }
  }
  
  unshift @$pipeline_analyses, $init_module;
  
  return $pipeline_analyses;
}

sub resource_classes {
  my ($self) = @_;
  return {
    %{$self->SUPER::resource_classes},
    'default' => { 'LSF' => '-q production-rh7' },
  };
}

1;
