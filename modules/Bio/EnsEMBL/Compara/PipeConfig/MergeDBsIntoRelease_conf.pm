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

Bio::EnsEMBL::Compara::PipeConfig::MergeDBsIntoRelease_conf

=head1 DESCRIPTION

A pipeline to merge some production databases onto the release one.
It is currently working well only with the "gene side" of Compara (protein_trees, families and ncrna_trees)
because synteny_region_id is not ranged by MLSS.

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MergeDBsIntoRelease_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division $COMPARA_DIV

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MergeDBsIntoRelease_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;   # For WHEN and INPUT_PLUS

use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_pipeline_name {         # Instead of merge_dbs_into_release
    return 'dbmerge';
}

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        # The target database
        'curr_rel_db'   => 'compara_curr',  # Again this is a URL or a registry name

        # How many tables can be dumped and re-created in parallel (too many will slow the process down)
        'copying_capacity'  => 5,

        # Do we want ANALYZE TABLE and OPTIMIZE TABLE on the final tables ?
        'analyze_optimize'  => 1,

        # Do we want to backup the target merge table before-hand ?
        'backup_tables'     => 1,

        # Do we want to be very picky and die if a table hasn't been listed above / isn't in the target database ?
        'die_if_unknown_table'      => 1,

        # All the source databases
        'src_db_aliases'    => {
            # Mapping 'db_alias' => 'db_location':
            #   'db_alias' is the alias used for the database within the registry config file
            #   'db_location' is the actual location of the database. Can be a URL or a registry name
        },

        # From these databases, only copy these tables. Other tables are ignored
        'only_tables'       => {
            # Mapping 'db_alias' => Arrayref of table names
            # Example:
            #   'master_db'     => [qw(mapping_session)],
        },

        # These tables have a unique source database. They are ignored in the other databases
        'exclusive_tables'  => {
            # Mapping 'table_name' => 'db_alias',
            # Example:
            #   'mapping_session'       => 'master_db',
        },

        # In these databases, ignore these tables
        'ignored_tables'    => {
            # Mapping 'db_alias' => Arrayref of table names
            'ncrna_db'      => [qw(ortholog_quality id_generator id_assignments datacheck_results)],
            'protein_db'    => [qw(ortholog_quality id_generator id_assignments datacheck_results)],
            'projection_db' => [qw(id_generator id_assignments)],
        },

   };
}

sub no_compara_schema {}    # Tell the base class not to create the Compara tables in the database


sub pipeline_wide_parameters {
    my $self = shift @_;

    my $src_db_aliases = $self->o('src_db_aliases');

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        # Trick to overcome the 2-step substitution of parameters (also used below in the "generate_job_list" analysis
        ref($src_db_aliases) ? %$src_db_aliases : (),

        'curr_rel_db'   => $self->o('curr_rel_db'),
        'analyze_optimize'  => $self->o('analyze_optimize'),
        'backup_tables'     => $self->o('backup_tables'),
        'move_components'   => $self->o('move_components'),
    }
}


sub hive_meta_table {
    my ($self) = @_;
    return {
        %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
        'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
    }
}


=head2 pipeline_analyses

    Description : Implements pipeline_analyses() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that defines the structure of the pipeline: analyses, jobs, rules, etc.
                  Here it defines three analyses:
                    * 'generate_job_list'           generates a list of tables to be copied / merged
                    * 'copy_table'                  dumps tables from source_db and re-creates them in pipeline_db
                    * 'merge_table'                 dumps tables from source_db and merges them into pipeline_db
                    * 'check_size'                  checks that the total number of rows in the table is as expected
                    * 'analyze_optimize'            (optional) runs ANALYZE TABLE and OPTIMIZE TABLE on the final tables

=cut

sub pipeline_analyses {
    my ($self) = @_;
    return [

        {   -logic_name => 'generate_job_list',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck',
            -parameters => {
                'ignored_tables'    => $self->o('ignored_tables'),
                'exclusive_tables'  => $self->o('exclusive_tables'),
                'only_tables'       => $self->o('only_tables'),
                'src_db_aliases'    => [ref($self->o('src_db_aliases')) ? keys %{$self->o('src_db_aliases')} : ()],
                'die_if_unknown_table'  => $self->o('die_if_unknown_table'),
            },
            -rc_name    => '2Gb_job',
            -input_ids  => [ {} ],
            -flow_into  => {
                'A->1'  => WHEN(
                            '#move_components#' => 'polyploid_move_back_factory'
                        ),
                '2->A'  => [ 'copy_table'  ],
                '3->A'  => WHEN(
                            '#backup_tables#' => 'backup_table',
                            ELSE 'disable_keys',
                        ),
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'dest_db_conn'  => '#curr_rel_db#',
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=InnoDB/ENGINE=MyISAM/"',
            },
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
            -flow_into     => WHEN( '#analyze_optimize#' => ['analyze_optimize'] ),
        },

        {   -logic_name => 'merge_factory_recursive',
            -module     => 'Bio::EnsEMBL::Hive::Examples::Factories::RunnableDB::GrabN',
            -flow_into => {
                '2->A' => { 'merge_table' => INPUT_PLUS },
                'A->1' => WHEN( '#_list_exhausted#' => [ 'enable_keys' ], ELSE [ 'merge_factory_recursive' ] ),
            },
        },

        {   -logic_name    => 'merge_table',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::CopyTable',
            -parameters    => {
                'dest_db_conn'  => '#curr_rel_db#',
                'mode'          => 'ignore',
                'skip_disable_vars' => 1,
            },
            -hive_capacity => $self->o('copying_capacity'),
        },

        {   -logic_name => 'check_size',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'db_conn'       => '#curr_rel_db#',
                'expected_size' => '= #n_total_rows#',
                'query'         => 'SELECT #key# FROM #table#',
            },
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
            -flow_into     => [
                WHEN( '#analyze_optimize#' => ['analyze_optimize'] ),
                WHEN( '#backup_tables#' => ['drop_backup'] ),
            ],
        },

        {   -logic_name => 'backup_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'db_conn'   => '#curr_rel_db#',
                'sql'       => [
                    'CREATE TABLE DBMERGEBACKUP_#table# LIKE #table#',
                    'INSERT INTO DBMERGEBACKUP_#table# SELECT * FROM #table#',
                ]
            },
            -flow_into  => [ 'disable_keys' ],
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
        },

        {   -logic_name => 'disable_keys',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'db_conn' => '#curr_rel_db#',
                'sql'     => [
                    'ALTER TABLE #table# DISABLE KEYS',
                ]
            },
            -flow_into => [ 'merge_factory_recursive' ],
        },

        {   -logic_name => 'enable_keys',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'db_conn' => '#curr_rel_db#',
                'sql'     => [
                    'ALTER TABLE #table# ENABLE KEYS',
                ]
            },
            -hive_capacity => $self->o('copying_capacity'),
            -flow_into => [ 'check_size' ],
        },

        {   -logic_name => 'drop_backup',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'db_conn'   => '#curr_rel_db#',
                'sql'       => 'DROP TABLE DBMERGEBACKUP_#table#',
            },
        },

        {   -logic_name => 'analyze_optimize',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'db_conn'   => '#curr_rel_db#',
                'sql'       => [
                    'ANALYZE TABLE #table#',
                    'OPTIMIZE TABLE #table#',
                ]
            },
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
        },

        {   -logic_name => 'polyploid_move_back_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory',
            -parameters => {
                'component_genomes' => 0,
                'normal_genomes'    => 0,
            },
            -flow_into => {
                2 => [ 'component_genome_dbs_move_back_factory' ],
            },
        },

        {   -logic_name => 'component_genome_dbs_move_back_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComponentGenomeDBFactory',
            -flow_into => {
                2 => {
                    'move_back_component_genes' => { 'source_gdb_id' => '#component_genome_db_id#', 'target_gdb_id' => '#principal_genome_db_id#'},
                },
            },
        },

        {   -logic_name => 'move_back_component_genes',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MoveComponentGenes',
            -hive_capacity => 3,
        },

    ];
}

1;


=head2 Example configurations

=over

=item If we have projection_db:

        'src_db_aliases'    => {
            #'protein_db'    => 'mysql://ensro@compara1/mm14_compara_homology_71',
            'ncrna_db'      => 'mysql://ensro@compara2/mp12_compara_nctrees_71',
            'family_db'     => 'mysql://ensro@compara4/lg4_compara_families_71',
            'projection_db' => 'mysql://ensro@compara3/mm14_homology_projections_71',
            'master_db'     => 'mysql://ensro@compara1/mm14_ensembl_compara_master',
        },

        'only_tables'       => {
            'master_db'     => [qw(mapping_session)],
        },

        'exclusive_tables'  => {
            'mapping_session'   => 'master_db',
            'gene_member'       => 'projection_db',
            'seq_member'        => 'projection_db',
            'sequence'          => 'projection_db',
        },

        'ignored_tables'    => {
        },

=item If we don't have projection_db:

        'src_db_aliases'    => {
            'protein_db'    => 'mysql://ensro@compara1/mm14_compara_homology_71',
            'ncrna_db'      => 'mysql://ensro@compara2/mp12_compara_nctrees_71',
            'family_db'     => 'mysql://ensro@compara4/lg4_compara_families_71',
            'master_db'     => 'mysql://ensro@compara1/mm14_ensembl_compara_master',
        },

        'only_tables'       => {
            'master_db'     => [qw(mapping_session)],
        },

        'exclusive_tables'  => {
            'mapping_session'   => 'master_db',
        },

        'ignored_tables'    => {
            'protein_db'    => [qw(gene_member seq_member sequence)],
        },

=item If we only have trees:

        'src_db_aliases'    => {
            'protein_db'    => 'mysql://ensro@compara1/mm14_compara_homology_71',
            'ncrna_db'      => 'mysql://ensro@compara2/mp12_compara_nctrees_71',
            'master_db'     => 'mysql://ensro@compara1/mm14_ensembl_compara_master',
        },

        'only_tables'       => {
            'master_db'     => [qw(mapping_session)],
        },

        'exclusive_tables'  => {
            'mapping_session'   => 'master_db',
        },

        'ignored_tables'    => {
        },

=item If we have genomic alignments:

        'src_db_aliases'    => {
            'sf5_epo_low_8way_fish_71' => 'mysql://ensro@compara2/sf5_epo_low_8way_fish_71',
            'sf5_ggal_acar_lastz_71' => 'mysql://ensro@compara2/sf5_ggal_acar_lastz_71',
            'sf5_olat_onil_lastz_71' => 'mysql://ensro@compara2/sf5_olat_onil_lastz_71',
            'sf5_olat_xmac_lastz_71' => 'mysql://ensro@compara2/sf5_olat_xmac_lastz_71',
            'kb3_ggal_csav_tblat_71' => 'mysql://ensro@compara3/kb3_ggal_csav_tblat_71',
            'kb3_ggal_drer_tblat_71' => 'mysql://ensro@compara3/kb3_ggal_drer_tblat_71',
            'kb3_ggal_mgal_lastz_71' => 'mysql://ensro@compara3/kb3_ggal_mgal_lastz_71',
            'kb3_ggal_xtro_tblat_71' => 'mysql://ensro@compara3/kb3_ggal_xtro_tblat_71',
            'kb3_hsap_ggal_lastz_71' => 'mysql://ensro@compara3/kb3_hsap_ggal_lastz_71',
            'kb3_hsap_ggal_tblat_71' => 'mysql://ensro@compara3/kb3_hsap_ggal_tblat_71',
            'kb3_mmus_ggal_lastz_71' => 'mysql://ensro@compara3/kb3_mmus_ggal_lastz_71',
            'kb3_pecan_20way_71' => 'mysql://ensro@compara3/kb3_pecan_20way_71',
            'sf5_compara_epo_3way_birds_71' => 'mysql://ensro@compara3/sf5_compara_epo_3way_birds_71',
            'sf5_olat_gmor_lastz_71' => 'mysql://ensro@compara3/sf5_olat_gmor_lastz_71',
            'sf5_compara_epo_6way_71' => 'mysql://ensro@compara4/sf5_compara_epo_6way_71',
            'sf5_ggal_tgut_lastz_71' => 'mysql://ensro@compara4/sf5_ggal_tgut_lastz_71',
            'master_db'     => 'mysql://ensro@compara1/mm14_ensembl_compara_master',
        },

        'only_tables'       => {
        },

        'exclusive_tables'  => {
        },

        'ignored_tables'    => {
            'kb3_pecan_20way_71'    => [qw(peptide_align_feature_% gene_member seq_member sequence)],
        },

=back

=cut
