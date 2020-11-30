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

use Bio::EnsEMBL::Compara::PipeConfig::Parts::LoadCoreMembers;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstRef;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstQuery;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # Inherit the generic ones

        'work_dir'     => $self->o('pipeline_dir'),
        'fasta_dir'    => $self->o('work_dir') . '/fasta/',
        'query_db_dir' => $self->o('work_dir') . '/query_diamond_db/',
        'ref_dump_dir' => $self->o('genome_dumps_dir'),

        'ref_blast_db' => undef,
        'blast_db'     => $self->o('ref_blast_db'),
        'compara_db'   => $self->pipeline_url(),
        'output_db'    => $self->pipeline_url(),
        'master_db'    => $self->pipeline_url(),
        'ncbi_db'      => 'ncbi_taxonomy',
        'member_db'    => $self->pipeline_url(),
        'reference_db' => 'rr_ref_master',
        'meta_host'    => 'mysql-ens-meta-prod-1',

        # Member loading parameters
        'include_reference'           => 1,
        'include_nonreference'        => 0,
        'include_patches'             => 0,
        'store_coding'                => 1,
        'store_ncrna'                 => 0,
        'store_others'                => 0,
        'store_exon_coordinates'      => 0,
        'store_related_pep_sequences' => 0, # do we want CDS sequence as well as protein seqs?

        # Member HC parameters
        'allow_ambiguity_codes'         => 1,
        'only_canonical'                => 0,
        'allow_missing_cds_seqs'        => 1, # set to 0 if we store CDS (see above)
        'allow_missing_coordinates'     => 0,
        'allow_missing_exon_boundaries' => 1, # set to 0 if exon boundaries are loaded (see above)

        'projection_source_species_names' => [ ],
        'curr_file_sources_locs'          => [ ],

        # DIAMOND e-hive parameters
        'blast_factory_capacity'   => 50,
        'blastpu_capacity'         => 150,
        'copy_alignments_capacity' => 50,
        'copy_trees_capacity'      => 50,
        'reuse_capacity'           => 3,
        'hc_capacity'              => 150,
        'decision_capacity'        => 150,
        'hc_priority'              => -10,
        'num_sequences_per_blast_job' => 200,
        'blast_params'                => '--max-hsps 1 --threads 4 -b1 -c1 --sensitive',
        'evalue_limit'                => '1e-6',

    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # Here we inherit creation of database, hive tables and compara tables

        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'fasta_dir', 'query_db_dir']), # Here we create directories

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
        'reference_db'     => $self->o('reference_db'),

        'blast_params'     => $self->o('blast_params'),
        'evalue_limit'     => $self->o('evalue_limit'),
        'diamond_exe'      => $self->o('diamond_exe'),

        'fasta_dir'        => $self->o('fasta_dir'),
        'query_db_dir'     => $self->o('query_db_dir'),
        'ref_dump_dir'     => $self->o('ref_dump_dir'),

        'reference_list'    => $self->o('reference_list'),
        'species_list_file' => $self->o('species_list_file'),
    };
}

sub resource_classes {
    my ($self) = @_;
    return {
        %{$self->SUPER::resource_classes('include_multi_threaded')},  # inherit the standard resource classes, incl. multi-threaded
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

    return [
        {   -logic_name => 'backbone_fire_db_prepare',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -input_ids  => [ { } ],
            -flow_into  => {
                '1->A'  => [ 'copy_ncbi_tables_factory' ],
                'A->1'  => [ 'backbone_fire_blast' ],
            },
        },

        {   -logic_name => 'backbone_fire_blast',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into     => {
                '1->A' => [ 'diamond_factory' ],
                'A->1' => [ 'do_something_with_paf_table' ],
            },
        },

        {   -logic_name    => 'diamond_factory',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory',
            -parameters    => {
                'step'  => $self->o('num_sequences_per_blast_job'),
            },
            -rc_name       => '500Mb_job',
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into     => {
                '2' => [ 'diamond_blastp' ],
                '1' => [ 'make_query_blast_db' ],
            },
        },

        {   -logic_name => 'do_something_with_paf_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::LoadCoreMembers::pipeline_analyses_copy_ncbi_and_core_genome_db($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstRef::pipeline_analyses_diamond_against_refdb($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstQuery::pipeline_analyses_diamond_against_query($self) },
    ];
}

1;
