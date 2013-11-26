=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 SYNOPSIS

    #1. update all databases' names and locations

    #2. initialize the pipeline:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::MergeDBsIntoRelease_conf -password <your_password>

    #3. run the beekeeper.pl

=head1 DESCRIPTION  

    A pipeline to merge some production databases onto the release one.
    It is currently working well only with the "gene side" of Compara (protein_trees, families and ncrna_trees).

=cut

package Bio::EnsEMBL::Compara::PipeConfig::MergeDBsIntoRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');


     
sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'host'            => 'compara4',    # where the pipeline database will be created
        'rel_suffix'      => '',            # an empty string by default, a letter otherwise

        'rel_with_suffix' => $self->o('ensembl_release').$self->o('rel_suffix'),
        'pipeline_name'   => 'pipeline_dbmerge_'.$self->o('rel_with_suffix'),   # also used to differentiate submitted processes

        'copying_capacity'  => 10,                                  # how many tables can be dumped and re-created in parallel (too many will slow the process down)

        # Do we want ANALYZE TABLE and OPTIMIZE TABLE on the final tables ?
        'analyze_optimize'  => 1,

        # Do we want to backup the target merge table before-hand ?
        'backup_tables'     => 1,

        'urls'              => {
            'master_db'     => 'mysql://ensro@compara1/sf5_ensembl_compara_master',
            'prev_rel_db'   => 'mysql://ensro@ens-livemirror/ensembl_compara_72',   # <----- make sure this refers to the previous release!

                                        # make sure that for the rest of the databases you have servers' and owners' names right:
            'curr_rel_db'   => 'mysql://ensadmin:'.$self->o('password').'@compara2/'.$self->o('ENV','USER').'_ensembl_compara_'.$self->o('ensembl_release'),

            'protein_db'    => 'mysql://ensro@compara1/mm14_compara_homology_'.$self->o('ensembl_release'),
            'ncrna_db'      => 'mysql://ensro@compara3/mp12_compara_nctrees_'.$self->o('ensembl_release'),
            'family_db'     => 'mysql://ensro@compara2/lg4_compara_families_'.$self->o('ensembl_release'),
            'projection_db' => 'mysql://ensro@compara3/mm14_homology_projections_'.$self->o('ensembl_release'),
        },

        'only_tables'       => {
            'prev_rel_db'   => [qw(stable_id_history)],
            'master_db'     => [qw(mapping_session)],
        },

        'exclusive_tables'  => {
            'mapping_session'   => 'master_db',
            'member'            => 'projection_db',
            'sequence'          => 'projection_db',
            'peptide_align_feature_%' => 'protein_db',
        },

        'ignored_tables'    => {
        },

   };
}


sub pipeline_wide_parameters {
    my $self = shift @_;

    my $urls = $self->o('urls');

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        # Trick to overcome the 2-step substitution of parameters (also used below in the "generate_job_list" analysis
        ref($urls) ? %$urls : (),
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
                'db_aliases'        => [ref($self->o('urls')) ? keys %{$self->o('urls')} : ()],
            },
            -input_ids  => [ {} ],
            -flow_into  => {
                2      => [ 'copy_table'  ],
                '3->A' => [ 'merge_table' ],
                $self->o('backup_tables') ? ('4->A' => [ 'backup_table' ]) : (),
                'A->4' => [ 'check_size' ],
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

        {   -logic_name    => 'merge_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'dest_db_conn'  => '#curr_rel_db#',
                'mode'          => 'topup',
            },
            -analysis_capacity => 1,                              # we can only have one worker of this kind to avoid conflicts of DISABLE KEYS / ENABLE KEYS / INSERT
            -hive_capacity => $self->o('copying_capacity'),       # allow several workers to perform identical tasks in parallel
            # we're waiting for all the backups to complete (even though we only need to wait for one of them)
            $self->o('backup_tables') ? (-wait_for => [ 'backup_table' ]) : (),
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

    ];
}

1;


=head3

If we have projection_db:

        'urls'              => {
            #'protein_db'    => 'mysql://ensro@compara1/mm14_compara_homology_71',
            'ncrna_db'      => 'mysql://ensro@compara2/mp12_compara_nctrees_71',
            'family_db'     => 'mysql://ensro@compara4/lg4_compara_families_71',
            'projection_db' => 'mysql://ensro@compara3/mm14_homology_projections_71',
            'prev_rel_db'   => 'mysql://ensro@ens-livemirror/ensembl_compara_70',

            #'curr_rel_db'   => 'mysql://ensro@compara3/kb3_ensembl_compara_71',
            'curr_rel_db'   => 'mysql://ensadmin:'.$self->o('password').'@compara3/mm14_test_final_db2',
            'master_db'     => 'mysql://ensro@compara1/sf5_ensembl_compara_master',
        },

        'only_tables'       => {
            'prev_rel_db'   => [qw(stable_id_history)],
            'master_db'     => [qw(mapping_session)],
        },

        'exclusive_tables'  => {
            'mapping_session'   => 'master_db',
            'member'            => 'projection_db',
            'sequence'          => 'projection_db',
        },

        'ignored_tables'    => {
        },

=cut


=head3

If we don't have projection_db:

        'urls'              => {
            'protein_db'    => 'mysql://ensro@compara1/mm14_compara_homology_71',
            'ncrna_db'      => 'mysql://ensro@compara2/mp12_compara_nctrees_71',
            'family_db'     => 'mysql://ensro@compara4/lg4_compara_families_71',
            'prev_rel_db'   => 'mysql://ensro@ens-livemirror/ensembl_compara_70',

            'curr_rel_db'   => 'mysql://ensro@compara3/kb3_ensembl_compara_71',
            'master_db'     => 'mysql://ensro@compara1/sf5_ensembl_compara_master',
        },

        'only_tables'       => {
            'prev_rel_db'   => [qw(stable_id_history)],
            'master_db'     => [qw(mapping_session)],
        },

        'exclusive_tables'  => {
            'mapping_session'   => 'master_db',
        },

        'ignored_tables'    => {
            'protein_db'    => [qw(member sequence)],
        },

=cut

=head3

If we only have trees:

        'urls'              => {
            'protein_db'    => 'mysql://ensro@compara1/mm14_compara_homology_71',
            'ncrna_db'      => 'mysql://ensro@compara2/mp12_compara_nctrees_71',

            'curr_rel_db'   => 'mysql://ensro@compara3/kb3_ensembl_compara_71',
            'master_db'     => 'mysql://ensro@compara1/sf5_ensembl_compara_master',
        },

        'only_tables'       => {
            'prev_rel_db'   => [qw(stable_id_history)],
            'master_db'     => [qw(mapping_session)],
        },

        'exclusive_tables'  => {
            'mapping_session'   => 'master_db',
        },

        'ignored_tables'    => {
        },

=cut

=head3

If we have genomic alignments:

        'urls'              => {
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

            'curr_rel_db'   => 'mysql://ensro@compara3/kb3_ensembl_compara_71',
            'master_db'     => 'mysql://ensro@compara1/sf5_ensembl_compara_master',
        },

        'only_tables'       => {
        },

        'exclusive_tables'  => {
        },

        'ignored_tables'    => {
            'kb3_pecan_20way_71'    => [qw(peptide_align_feature_% member sequence)],
        },

=cut

