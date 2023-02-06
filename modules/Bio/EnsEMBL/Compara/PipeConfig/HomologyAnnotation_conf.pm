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

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::HomologyAnnotation_conf -host mysql-ens-compara-prod-X -port XXXX \
        --species species_1 --species species_2 --species species_n

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::HomologyAnnotation_conf -host mysql-ens-compara-prod-X -port XXXX \
        --species_list path/to/one_species_per_line_file.txt

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
use Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFactory;
use Bio::EnsEMBL::Compara::PipeConfig::Parts::PerSpeciesCopyFactory;

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # Inherit the generic ones

        'pipeline_name'     => 'blastocyst_' . $self->o('rel_with_suffix'),
        # Back compatibility for production team's use of '--pass' instead of '--password'
        'pass'     => undef,
        'password' => $self->o('pass') ? $self->o('pass') : $self->o('password'),

        # Mandatory species input, one or the other only
        'species_list'  => undef,
        'species'       => [ ],
        'division'      => 'homology_annotation',
        # Mandatory server host for species homology databases
        'homology_host' => 'mysql-ens-sta-5',
        # registry_file compatibility so can be overridden if necessary
        'registry_file' => $self->o('reg_conf'),

        # Directories to write to
        'work_dir'     => $self->o('pipeline_dir'),
        'dump_path'    => $self->o('work_dir'),
        # Directories the reference genome pipeline dumps to
        'ref_dump_dir' => $self->o('ref_member_dumps_dir'),
        # Directory for diamond and fasta files for query genome
        'members_dumps_dir' => $self->o('dump_path'),
        # Directory for species set record of references to query
        'species_set_record' => $self->o('rr_species_set_record'),
        # Compara schema file path
        'schema_file' => $self->o('schema_file_sql'),
        # Path to db_cmd.pl script
        'db_cmd_path' => $self->o('hive_root_dir') . '/scripts/db_cmd.pl',
        # Copy databases program
        'copy_program' => $self->o('populate_per_genome_database_exe'),

        # Set mandatory databases
        'compara_db'   => $self->pipeline_url(),
        'output_db'    => $self->o('compara_db'),
        'member_db'    => $self->o('compara_db'),
        'ncbi_db'      => 'ncbi_taxonomy',
        'rr_ref_db'    => 'compara_references',
        'meta_host'    => 'mysql-ens-meta-prod-1',

        # Member loading parameters - matches reference genome members
        'include_reference'           => 1,
        'include_nonreference'        => 0,
        'include_patches'             => 0,
        'store_coding'                => 1, # at the moment we are only loading the proteins
        'store_ncrna'                 => 0,
        'store_others'                => 0,
        'store_exon_coordinates'      => 0,
        'store_related_pep_sequences' => 0, # do we want CDS sequences as well as protein seqs?
        'skip_dna'                    => 1, # skip storing the dna information

        # Member HC parameters
        'allow_ambiguity_codes'         => 1,
        'only_canonical'                => 0,
        'allow_missing_cds_seqs'        => 1, # set to 0 if we store CDS (see above)
        'allow_missing_coordinates'     => 1,
        'allow_missing_exon_boundaries' => 1, # set to 0 if exon boundaries are loaded (see above)

        'projection_source_species_names' => [ ],
        'curr_file_sources_locs'          => [ ],

        # Whole db DC parameters
        'dc_pipeline_grp'  => ['compara_blastocyst'],
        'dc_compara_grp'   => ['compara_homology_annotation'],
        'db_type'          => ['compara'],
        'output_dir_path'  => $self->o('work_dir') . '/datachecks/',
        'overwrite_files'  => 1,
        'failures_fatal'   => 1, # no DC failure tolerance
        'old_server_uri'   => [$self->o('compara_db')],
        'db_name'          => $self->o('dbowner') . '_' . $self->o('pipeline_name'),
        'ref_dbname'       => 'ensembl_compara_references',

        #Dump script location
        'dump_homologies_script' => $self->check_exe_in_ensembl('ensembl-compara/scripts/dumps/dump_homologies.py'),

        #Dump dir path for GenomeDirectoryPath module
        'dump_dir' => $self->o('work_dir') . '/homology_tsv_dump_dir',
        'ftp_root' => undef,

        # List of tables to copy to per-species compara database
        'table_list' => [
            "genome_db",
            "method_link_species_set",
            "gene_member",
            "peptide_align_feature",
            "homology",
        ],

        # DIAMOND e-hive parameters
        'blast_factory_capacity'   => 50,
        'blastpu_capacity'         => 150,

        # DIAMOND runnable parameters
        'num_sequences_per_blast_job' => 200,
        'blast_params'                => '--threads 4 -b1 -c1 --top 50 --dbsize 1000000 --sensitive',
        'evalue_limit'                => '1e-5',

    };
}

sub pipeline_create_commands {
    my ($self) = @_;

    my $results_table_sql = q/
        CREATE TABLE datacheck_results (
            submission_job_id INT,
            dbname VARCHAR(255) NOT NULL,
            passed INT,
            failed INT,
            skipped INT,
            INDEX submission_job_id_idx (submission_job_id)
        );
    /;

    return [
        @{$self->SUPER::pipeline_create_commands},  # Here we inherit creation of database, hive tables and compara tables

        $self->pipeline_create_commands_rm_mkdir(['work_dir', 'output_dir_path', 'dump_dir']), # Here we create directories
        $self->pipeline_create_commands_rm_mkdir(['species_set_record'], undef, 1),
        $self->db_cmd($results_table_sql),

    ];
}

sub pipeline_wide_parameters {  # These parameter values are visible to all analyses, can be overridden by parameters{} and input_id{}
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},          # Here we inherit anything from the base class

        'ncbi_db'           => $self->o('ncbi_db'),
        'member_db'         => $self->o('member_db'),
        'output_db'         => $self->o('output_db'),
        'rr_ref_db'         => $self->o('rr_ref_db'),

        'blast_params'      => $self->o('blast_params'),
        'evalue_limit'      => $self->o('evalue_limit'),
        'diamond_exe'       => $self->o('diamond_exe'),

        'members_dumps_dir' => $self->o('members_dumps_dir'),
        'ref_dump_dir'      => $self->o('ref_dump_dir'),
        'dump_path'         => $self->o('dump_path'),

        'reg_conf'          => $self->o('reg_conf'),

        'output_dir_path'  => $self->o('output_dir_path'),
        'overwrite_files'  => $self->o('overwrite_files'),
        'failures_fatal'   => $self->o('failures_fatal'),
        'db_name'          => $self->o('db_name'),

        'dump_homologies_script' => $self->o('dump_homologies_script'),
        'dump_dir' => $self->o('dump_dir'),
        'ftp_root' => $self->o('ftp_root'),
        'ref_dbname' => $self->o('ref_dbname'),

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

    my %dc_parameters = (
        'datacheck_groups' => $self->o('dc_pipeline_grp'),
        'db_type'          => $self->o('db_type'),
        'old_server_uri'   => $self->o('old_server_uri'),
        'registry_file'    => undef,
    );

    return [

        {   -logic_name      => 'core_species_factory',
            -module          => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::SpeciesFactory',
            -max_retry_count => 1,
            -input_ids       => [{
                'registry_file'      => $self->o('registry_file'),
                'species_list'       => $self->o('species'),
                'species_list_file'  => $self->o('species_list'),
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
                'A->1'  => [ 'backbone_fire_analyses_prepare' ],
            },
        },

        {   -logic_name => 'backbone_fire_analyses_prepare',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A'  => [ 'diamond_factory' ],
                'A->1'  => [ 'backbone_dc_and_copy_db' ],
            },
        },

        {   -logic_name    => 'diamond_factory',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory',
            -parameters    => {
                'step'  => $self->o('num_sequences_per_blast_job'),
            },
            -rc_name       => '1Gb_job',
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into     => {
                '2->A' => [ 'diamond_blastp' ],
                '1->A' => [ 'make_query_blast_db' ],
                'A->3' => [ 'create_mlss_and_batch_members' ],
            },
        },

        {   -logic_name => 'create_mlss_and_batch_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::CreateSuperficialMLSS',
            -rc_name    => '4Gb_job',
            -flow_into  => {
                2 => { 'parse_paf_for_rbbh' => { 'member_id_list' => '#member_id_list#', 'target_genome_db_id' => '#ref_genome_db_id#', 'genome_db_id' => '#genome_db_id#' } },
            }
        },

        {   -logic_name => 'parse_paf_for_rbbh',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::ParsePAFforBHs',
            -rc_name    => '2Gb_job',
            -hive_capacity => 100,
        },

        {   -logic_name => 'backbone_dc_and_copy_db',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -flow_into  => {
                '1->A'  => { 'datacheck_factory' => { 'compara_db' => $self->o('compara_db'), %dc_parameters } },
                'A->1'  => [ 'create_db_factory' ],
            }
        },

        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::LoadCoreMembers::pipeline_analyses_copy_ncbi_and_core_genome_db($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstRef::pipeline_analyses_diamond_against_refdb($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DiamondAgainstQuery::pipeline_analyses_diamond_against_query($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::DataCheckFactory::pipeline_analyses_datacheck_factory($self) },
        @{ Bio::EnsEMBL::Compara::PipeConfig::Parts::PerSpeciesCopyFactory::pipeline_analyses_create_and_copy_per_species_db($self) },

    ];
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    delete $analyses_by_name->{'datacheck_fan'}->{'-flow_into'}->{2};
    delete $analyses_by_name->{'datacheck_fan_high_mem'}->{'-flow_into'}->{2};
    $analyses_by_name->{'datacheck_factory'}->{'-parameters'} = {'dba' => '#compara_db#'};
    $analyses_by_name->{'datacheck_fan'}->{'-flow_into'}->{0} = ['jira_ticket_creation'];
    $analyses_by_name->{'datacheck_fan_high_mem'}->{'-flow_into'}->{0} = ['jira_ticket_creation'];
    $analyses_by_name->{'store_results'}->{'-parameters'} = {'dbname' => '#db_name#'};
}

1;
