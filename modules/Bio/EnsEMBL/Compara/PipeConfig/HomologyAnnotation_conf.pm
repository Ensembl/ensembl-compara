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

        # Directories to write to
        'work_dir'     => $self->o('pipeline_dir'),
        'dump_path'    => $self->o('work_dir'),
        # Directories the reference genome pipeline dumps to
        'ref_dump_dir' => $self->o('ref_member_dumps_dir'),
        # Directory for diamond and fasta files for query genome
        'members_dumps_dir' => $self->o('dump_path'),

        # Set mandatory databases
        'compara_db'   => $self->pipeline_url(),
        'output_db'    => $self->o('compara_db'),
        'master_db'    => $self->o('compara_db'),
        'member_db'    => $self->o('compara_db'),
        'ncbi_db'      => 'ncbi_taxonomy',
        'rr_ref_db'    => 'rr_ref_master',
        'meta_host'    => 'mysql-ens-meta-prod-1',

        # Member loading parameters - matches reference genome members
        'include_reference'           => 1,
        'include_nonreference'        => 0,
        'include_patches'             => 0,
        'store_coding'                => 1, # at the moment we are only loading the proteins
        'store_ncrna'                 => 0,
        'store_others'                => 0,
        'store_exon_coordinates'      => 0,
        'store_related_pep_sequences' => 0, # do we want CDS sequence as well as protein seqs?
        'skip_dna'                    => 1, # we skip the dna in this case

        # Member HC parameters
        'allow_ambiguity_codes'         => 1,
        'only_canonical'                => 0,
        'allow_missing_cds_seqs'        => 1, # set to 0 if we store CDS (see above)
        'allow_missing_coordinates'     => 1,
        'allow_missing_exon_boundaries' => 1, # set to 0 if exon boundaries are loaded (see above)

        'projection_source_species_names' => [ ],
        'curr_file_sources_locs'          => [ ],

        # DIAMOND e-hive parameters
        'blast_factory_capacity'   => 50,
        'blastpu_capacity'         => 150,
        'copy_alignments_capacity' => 50,
        'copy_trees_capacity'      => 50,

        # Other e-hive parameters
        'reuse_capacity'           => 3,
        'hc_capacity'              => 150,
        'decision_capacity'        => 150,
        'hc_priority'              => -10,

        # DIAMOND runnable parameters
        'num_sequences_per_blast_job' => 200,
        'blast_params'                => '--max-hsps 1 --threads 4 -b1 -c1 --top 20 --dbsize 1000000 --sensitive',
        'evalue_limit'                => '1e-10',

        # Set hybrid registry file that both metadata production and compara understand
        'reg_conf'      => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/conf/homology_annotation/production_reg_conf.pl',
        'registry_file' => $self->o('reg_conf'),

        # Mandatory species input, one or the other only
        'species_list_file' => undef,
        'species_list'      => [ ],
        'division'          => 'homology_annotation',

    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # Here we inherit creation of database, hive tables and compara tables

        $self->pipeline_create_commands_rm_mkdir(['work_dir']), # Here we create directories

    ];
}

sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    };
}

sub pipeline_wide_parameters {  # These parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # Here we inherit anything from the base class

        'ncbi_db'           => $self->o('ncbi_db'),
        'member_db'         => $self->o('member_db'),
        'master_db'         => $self->o('master_db'),
        'output_db'         => $self->o('output_db'),
        'rr_ref_db'         => $self->o('rr_ref_db'),

        'blast_params'      => $self->o('blast_params'),
        'evalue_limit'      => $self->o('evalue_limit'),
        'diamond_exe'       => $self->o('diamond_exe'),

        'members_dumps_dir' => $self->o('members_dumps_dir'),
        'ref_dump_dir'      => $self->o('ref_dump_dir'),
        'dump_path'         => $self->o('dump_path'),

        'reg_conf'          => $self->o('reg_conf'),
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

        {   -logic_name      => 'core_species_factory',
            -module          => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::SpeciesFactory',
            -max_retry_count => 1,
            -input_ids       => [{
                'registry_file'      => $self->o('registry_file'),
                'species_list'       => $self->o('species_list'),
                'species_list_file'  => $self->o('species_list_file'),
            },],
            -flow_into       => {
                8 => [ 'backbone_fire_db_prepare' ],
            },
            -hive_capacity   => 1,
        },

        {   -logic_name => 'backbone_fire_db_prepare',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A'  => [ 'copy_ncbi_tables_factory' ],
                'A->1'  => [ 'diamond_factory' ],
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
                '2' => [ 'diamond_blastp', 'parse_paf_for_rbbh' ],
                '1' => [ 'make_query_blast_db' ],
            },
        },

        {   -logic_name => 'parse_paf_for_rbbh',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::ParsePAFforBHs',
            -wait_for   => [
                'diamond_blastp',
                'diamond_blastp_ref_to_query',
                'diamond_blastp_himem',
                'diamond_blastp_ref_to_query_himem',
            ]
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::LoadCoreMembers::pipeline_analyses_copy_ncbi_and_core_genome_db($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstRef::pipeline_analyses_diamond_against_refdb($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstQuery::pipeline_analyses_diamond_against_query($self) },
    ];
}

1;
