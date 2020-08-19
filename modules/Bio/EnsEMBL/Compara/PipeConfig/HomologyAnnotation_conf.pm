=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::HomologyAnnotation_conf

=head1 DESCRIPTION

The PipeConfig file for the pipeline that annotates gene members by homology

=cut


package Bio::EnsEMBL::Compara::PipeConfig::HomologyAnnotation_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.5;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS

use Bio::EnsEMBL::Compara::PipeConfig::Parts::CopyNCBIandGenomeDB;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::BLASTpAgainstRef;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # Inherit the generic ones

        'species_set_id'    => undef,
        'mlss_id'           => undef,
        'do_not_reuse_list' => [ ],

        'work_dir'  => $self->o('pipeline_dir'),
        'fasta_dir' => $self->o('work_dir') . '/fasta/',

        'ref_blast_db' => undef,
        'blast_db'     => $self->o('ref_blast_db'),
        'output_db'    => $self->pipeline_url(),

        'method_link_dump_file' => $self->check_file_in_ensembl('ensembl-compara/sql/method_link.txt'),

        'master_db' => 'compara_master',
        'ncbi_db'   => $self->o('master_db'),
        'member_db' => 'compara_members',

        'projection_source_species_names' => [ ],

        'species_tree_input_file'         => undef,
        'update_threshold_trees'          => 0.2,
        'use_timetree_times'              => 0,

        'allow_ambiguity_codes'     => 1,
        'allow_missing_coordinates' => 0,
        'allow_missing_cds_seqs'    => 0,

        'blast_factory_capacity'   => 50,
        'blastpu_capacity'         => 150,
        'copy_alignments_capacity' => 50,
        'copy_trees_capacity'      => 50,
        'reuse_capacity'           => 3,
        'hc_capacity'              => 150,
        'decision_capacity'        => 150,
        'hc_priority'              => -10,

        'num_sequences_per_blast_job'   => 50,
        'all_blast_params'              => [ 35, 50, '-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix PAM70 -word_size 2', '1e-6' ],
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # Here we inherit creation of database, hive tables and compara tables

        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'fasta_dir']), # Here we create directories

    ];
}

sub pipeline_wide_parameters {  # These parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # Here we inherit anything from the base class
        'ncbi_db'          => $self->o('ncbi_db'),
        'member_db'        => $self->o('member_db'),
        'master_db'        => $self->o('master_db'),
        'output_db'        => $self->o('output_db'),
        'species_set_id'   => $self->o('species_set_id'),
        'all_blast_params' => $self->o('all_blast_params'),
        'fasta_dir'        => $self->o('fasta_dir'),
    };
}

sub core_pipeline_analyses {
    my ($self) = @_;

    my %hc_analysis_params = (
            -analysis_capacity  => $self->o('hc_capacity'),
            -priority           => $self->o('hc_priority'),
            -batch_size         => 20,
    );

    my %decision_analysis_params = (
            -analysis_capacity  => $self->o('decision_capacity'),
            -priority           => $self->o('hc_priority'),
            -batch_size         => 20,
    );

    my %blastp_parameters = (
        'blast_bin_dir'         => $self->o('blast_bin_dir'),
        'blast_params'          => "#expr( #all_blast_params#->[#param_index#]->[2])expr#",
        'evalue_limit'          => "#expr( #all_blast_params#->[#param_index#]->[3])expr#",
    );

    return [
        {   -logic_name => 'backbone_fire_db_prepare',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::AssertMatchingVersions',
            -input_ids  => [ { 'manual_ok' => 1, } ],
            -flow_into  => {
                '1->A'  => [ 'copy_ncbi_tables_factory' ],
                'A->1'  => [ 'backbone_fire_blast' ],
            },
        },

        {   -logic_name => 'backbone_fire_blast',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into     => {
                '1->A' => [ 'blast_factory' ],
                'A->1' => [ 'do_something_with_paf_table' ],
            },
        },

        {   -logic_name => 'blast_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory',
            -parameters => {
                'species_set_id'    => $self->o('species_set_id'),
                'step'              => $self->o('num_sequences_per_blast_job'),
            },
            -rc_name       => '500Mb_job',
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into     => {
                '2' => { 'blastp_unannotated' => INPUT_PLUS() }
            },
        },

        {   -logic_name => 'do_something_with_paf_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::CopyNCBIandGenomeDB::pipeline_analyses_copy_ncbi_and_genome_db($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::BLASTpAgainstRef::pipeline_analyses_blastp_against_refdb($self) },
    ];
}

1;

