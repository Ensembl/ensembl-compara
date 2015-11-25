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

=head1 SYNOPSIS

    #1. update all databases' names and locations

    #2. initialize the pipeline:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblMergeDBsIntoRelease_conf -password <your_password>

    #3. run the beekeeper.pl

=head1 DESCRIPTION

A pipeline to merge some production databases onto the release one.
It is currently working well only with the "gene side" of Compara (protein_trees, families and ncrna_trees)
because synteny_region_id is not ranged by MLSS.

The default paramters work well in the context of an Ensembl Compara release (with a well-configured
Registry file). If the list of source-databases is different, have a look at the bottom of the file
for alternative configurations.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblMergeDBsIntoRelease_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;

use base ('Bio::EnsEMBL::Compara::PipeConfig::MergeDBsIntoRelease_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        # Where the pipeline database will be created
        'host'            => 'compara5',

        # Also used to differentiate submitted processes
        'pipeline_name'   => 'pipeline_dbmerge_'.$self->o('rel_with_suffix'),

        # A registry file to avoid having to use URLs
        'reg_conf' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/production_reg_conf.pl",

        # All the source databases
        'src_db_aliases'    => {
            'master_db'     => 'compara_master',
            'protein_db'    => 'compara_ptrees',
            'ncrna_db'      => 'compara_nctrees',
            'family_db'     => 'compara_families',
            'projection_db' => 'mysql://ensro@compara5/lg4_homology_projections_'.$self->o('ensembl_release'),
        },
        # The target database
        'curr_rel_db'   => 'compara_curr',

        # From these databases, only copy these tables
        'only_tables'       => {
            # Cannot be copied by populate_new_database because it doesn't contain the new mapping_session_ids yet
            'master_db'     => [qw(mapping_session)],
        },

        # These tables have a unique source. Content from other databases is ignored
        'exclusive_tables'  => {
            'mapping_session'   => 'master_db',
            'gene_member'       => 'projection_db',
            'seq_member'        => 'projection_db',
            'sequence'          => 'projection_db',
            'peptide_align_feature_%' => 'protein_db',
        },

        # In these databases, ignore these tables
        'ignored_tables'    => {
            #'protein_db'        => [qw(gene_tree_node)],
            'protein_db'        => [qw(all_cov_ortho poor_cov_ortho poor_cov_2 dubious_seqs)],
            #'family_db' => [qw(gene_member seq_member sequence tmp_job job_summary test_length)],
        },

   };
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

=item If we don't have families yet

        # All the source databases
        'src_db_aliases'    => {
            'master_db'     => 'compara_master', ???
            'protein_db'    => 'compara_ptrees',
            'ncrna_db'      => 'compara_nctrees',
            'projection_db' => 'mysql://ensro@compara5/lg4_homology_projections_'.$self->o('ensembl_release'),
        },

        # From these databases, only copy these tables
        'only_tables'       => {
            # Cannot be copied by populate_new_database because it doesn't contain the new mapping_session_ids yet
            'master_db'     => [qw(mapping_session)], ???
        },

        # These tables have a unique source. Content from other databases is ignored
        'exclusive_tables'  => {
            'mapping_session'   => 'master_db', ???
            'gene_member'       => 'projection_db',
            'seq_member'        => 'projection_db',
            'sequence'          => 'projection_db',
            'peptide_align_feature_%' => 'protein_db',
        },

        # In these databases, ignore these tables
        'ignored_tables'    => {
        },

=item If only families are left to merge

        # All the source databases
        'src_db_aliases'    => {
            'master_db'     => 'compara_master',
            'family_db'     => 'compara_families',
        },

        # From these databases, only copy these tables
        'only_tables'       => {
            # Cannot be copied by populate_new_database because it doesn't contain the new mapping_session_ids yet
            'master_db'     => [qw(mapping_session)],
        },

        # These tables have a unique source. Content from other databases is ignored
        'exclusive_tables'  => {
            'mapping_session'   => 'master_db',
        },

        # In these databases, ignore these tables
        'ignored_tables'    => {
            'family_db' => [qw(gene_member seq_member sequence)],
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

