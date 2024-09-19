=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneSetQC

=head1 DESCRIPTION

This file contains the main parts needed to run GeneSetQC in a pipeline.
It is used to form the main GeneSetQC pipeline, but is also embedded in
the ProteinTrees

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::GeneSetQC;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf; # For WHEN and INPUT_PLUS

use strict;
use warnings;

sub pipeline_analyses_GeneSetQC {
    my ($self) = @_;
    return [
        {   -logic_name => 'get_species_set',
            -module     =>  'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
        #    -parameters =>  {'compara_db'   => $self->o('compara_db')},
            -flow_into  =>  {
                '2->A'       => ['get_split_genes'],
                'A->2'   =>  ['gene_qc_funnel_check'],
            },
            -hive_capacity  => $self->o('genesetQC_capacity'),
            -rc_name => '2Gb_job',
        },

        {
            -logic_name     => 'get_split_genes',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::GetSplitGenes',
            -flow_into      =>  {
                1   =>  ['get_long_short_orth_genes','get_orphaned_genes','get_ambiguous'],
                2   =>  ['?table_name=gene_member_qc'],
            },
            -hive_capacity  => 50,
            -batch_size     => 1,
        },

        {
            -logic_name =>  'get_long_short_orth_genes',
            -module     =>  'Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindGeneFragments',
            -parameters =>  {
                'gene_status' => 'long-short',
                'coverage_threshold' => $self->o('coverage_threshold'), 
                'species_threshold' => $self->o('species_threshold'),
                },
            -flow_into  => {
                '2'  => ['?table_name=gene_member_qc'],
                '-1' => ['get_long_short_orth_genes_himem'],
            },
            -analysis_capacity  => 250,
            -rc_name => '1Gb_job',
        },
        
        {
            -logic_name =>  'get_long_short_orth_genes_himem',
            -module     =>  'Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindGeneFragments',
            -parameters =>  {
                'gene_status' => 'long-short',
                'coverage_threshold' => $self->o('coverage_threshold'), 
                'species_threshold' => $self->o('species_threshold'),
                },
            -flow_into  => {
                2   => ['?table_name=gene_member_qc'],
            },
            -analysis_capacity  => 250,
            -rc_name => '2Gb_job',
        },

        {
            -logic_name     =>  'get_orphaned_genes',
            -module         =>  'Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindGeneFragments',
            -parameters     =>  { 
                'gene_status' => 'orphaned', 
                'coverage_threshold' => $self->o('coverage_threshold'), 
                'species_threshold' => $self->o('species_threshold'), 
                },
            -flow_into      =>  {
                2   => ['?table_name=gene_member_qc'],
            },
            -analysis_capacity  => 2,
            -hive_capacity      => 10,
        },

        {
            -logic_name     =>  'get_ambiguous',
            -module         =>  'Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::FindGeneFragments',
            -rc_name        =>  '1Gb_job',
            -parameters     =>  {
                'gene_status'                   => 'ambiguous_sequence',
                'missing_sequence_threshold'    => $self->o('missing_sequence_threshold'),
                },
            -flow_into      =>  {
                2   => ['?table_name=gene_member_qc'],
            },
            -analysis_capacity  => 50,
        },

        {   -logic_name => 'gene_qc_funnel_check',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::FunnelCheck',
            -flow_into  => { 2 => { 'store_tags' => INPUT_PLUS() } },
        },

        {
            -logic_name => 'store_tags',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::StoreStatsAsTags',
            -analysis_capacity  => 10,

        },
    ];
}


1;
