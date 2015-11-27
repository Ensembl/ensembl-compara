=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Not all the parameters are defined here. Have a look at PipeConfig::Example::*MergeDBsIntoRelease_conf for
real-life implementations.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MergeDBsIntoRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::EnsemblGeneric_conf');

     
sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        # How many tables can be dumped and re-created in parallel (too many will slow the process down)
        'copying_capacity'  => 10,

        # Do we want ANALYZE TABLE and OPTIMIZE TABLE on the final tables ?
        'analyze_optimize'  => 1,

        # Do we want to backup the target merge table before-hand ?
        'backup_tables'     => 1,

        # A registry file to avoid having to use only URLs
        #'reg_conf' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/production_reg_conf.pl",

        # All the source databases
        #'src_db_aliases'    => {
        #    'master_db'     => 'compara_master',
        #    'protein_db'    => 'compara_ptrees',
        #    'ncrna_db'      => 'compara_nctrees',
        #    'family_db'     => 'compara_families',
        #    'projection_db' => 'mysql://ensro@compara5/lg4_homology_projections_'.$self->o('ensembl_release'),
        #},
        # The target database
        #'curr_rel_db'   => 'compara_curr',

        # From these databases, only copy these tables
        #'only_tables'       => {
        #    # Cannot be copied by populate_new_database because it doesn't contain the new mapping_session_ids yet
        #    'master_db'     => [qw(mapping_session)],
        #},

        # These tables have a unique source. Content from other databases is ignored
        #'exclusive_tables'  => {
        #    'mapping_session'   => 'master_db',
        #    'gene_member'       => 'projection_db',
        #    'seq_member'        => 'projection_db',
        #    'sequence'          => 'projection_db',
        #    'peptide_align_feature_%' => 'protein_db',
        #},

        # In these databases, ignore these tables
        #'ignored_tables'    => {
        #    #'protein_db'        => [qw(gene_tree_node)],
        #    'protein_db'        => [qw(all_cov_ortho poor_cov_ortho poor_cov_2 dubious_seqs)],
        #    #'family_db' => [qw(gene_member seq_member sequence tmp_job job_summary test_length)],
        #},

        # When everything is copied and merged, apply the following scripts
        'extra_sql_cmds'    => [
            $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/production/populate_member_production_counts_table.sql',
        ],
   };
}


sub resource_classes {
    my ($self) = @_;

    return {
        %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class

        'default' => { 'LSF' => ['', '--reg_conf '.$self->o('reg_conf')], 'LOCAL' => ['', '--reg_conf '.$self->o('reg_conf')] },
    };
}


sub pipeline_wide_parameters {
    my $self = shift @_;

    my $src_db_aliases = $self->o('src_db_aliases');

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        # Trick to overcome the 2-step substitution of parameters (also used below in the "generate_job_list" analysis
        ref($src_db_aliases) ? %$src_db_aliases : (),
        'curr_rel_db'   => $self->o('curr_rel_db'),
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

        {   -logic_name => 'pipeline_start',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -input_ids  => [ {} ],
            -flow_into  => {
                '1->A' => [ 'generate_job_list' ],
                'A->1' => [ 'extra_cmd_list' ],
            },
        },

        {   -logic_name => 'generate_job_list',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::DBMergeCheck',
            -parameters => {
                'ignored_tables'    => $self->o('ignored_tables'),
                'exclusive_tables'  => $self->o('exclusive_tables'),
                'only_tables'       => $self->o('only_tables'),
                'src_db_aliases'    => [ref($self->o('src_db_aliases')) ? keys %{$self->o('src_db_aliases')} : ()],
            },
            -flow_into  => {
                2      => [ 'copy_table'  ],
                3      => [ $self->o('backup_tables') ? 'backup_table' : 'merge_factory' ],
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
            -flow_into     => [ $self->o('analyze_optimize') ? ('analyze_optimize') : () ],
        },

        {   -logic_name => 'merge_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'column_names'  => [ 'src_db_conn' ],
            },
            -flow_into  => {
                '2->A' => [ 'merge_table' ],
                'A->1' => [ 'check_size' ],
            },
        },
        {   -logic_name    => 'merge_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'dest_db_conn'  => '#curr_rel_db#',
                'mode'          => 'topup',
            },
            -analysis_capacity => 1,                              # we can only have one worker of this kind to avoid conflicts of DISABLE KEYS / ENABLE KEYS / INSERT
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
        },

        {   -logic_name => 'check_size',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck',
            -parameters => {
                'db_conn'       => '#curr_rel_db#',
                'expected_size' => '= #n_total_rows#',
                'inputquery'    => 'SELECT #key# FROM #table#',
            },
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
            -flow_into     => [
                $self->o('analyze_optimize') ? ('analyze_optimize') : (),
                $self->o('backup_tables') ? ('drop_backup') : ()
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
            -flow_into  => [ 'merge_factory' ],
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
        },

        {   -logic_name => 'drop_backup',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'db_conn'   => '#curr_rel_db#',
                'sql'       => 'DROP TABLE DBMERGEBACKUP_#table#',
            },
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
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

        {   -logic_name => 'extra_cmd_list',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'column_names' => [ 'sql_file' ],
                'inputlist'    => $self->o('extra_sql_cmds'),
            },
            -flow_into => {
                2 => [ 'extra_cmd_run' ],
            },
        },


        {   -logic_name     => 'extra_cmd_run',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::DbCmd',
            -parameters     => {
                'db_conn'       => '#curr_rel_db#',
                'input_file'    => '#sql_file#',
            },
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

