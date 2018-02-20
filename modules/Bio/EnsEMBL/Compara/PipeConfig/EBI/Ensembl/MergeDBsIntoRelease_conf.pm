=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::MergeDBsIntoRelease_conf

=head1 SYNOPSIS

    #1. update all databases' names and locations

    #2. initialize the pipeline:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::MergeDBsIntoRelease_conf -password <your_password> -host <> -port <>

    #3. run the beekeeper.pl

=head1 DESCRIPTION

A pipeline to merge some production databases onto the release one.
It is currently working well only with the "gene side" of Compara (protein_trees, families and ncrna_trees)
because synteny_region_id is not ranged by MLSS.

The default paramters work well in the context of an Ensembl Compara release (with a well-configured
Registry file). If the list of source-databases is different, have a look at the bottom of the base file
for alternative configurations.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::MergeDBsIntoRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::MergeDBsIntoRelease_conf');


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

        # Do we want to be very picky and die if a table hasn't been listed above / isn't in the target database ?
        'die_if_unknown_table'      => 1,

        # A registry file to avoid having to use only URLs
        'reg_conf' => $self->o('ensembl_cvs_root_dir')."/ensembl-compara/scripts/pipeline/production_reg_conf.pl",

        # All the source databases
        'src_db_aliases'    => {
           'master_db'      => 'mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_master',
           'protein_db'     => 'mysql://ensro@mysql-ens-compara-prod-1:4485/waakanni_protein_trees_92',
           'ncrna_db'       => 'mysql://ensro@mysql-ens-compara-prod-4:4401/mateus_compara_nctrees_92',
           'family_db'      => 'mysql://ensro@mysql-ens-compara-prod-1:4485/waakanni_families_92',
           'mouse_prot_db'  => 'mysql://ensro@mysql-ens-compara-prod-3:4523/carlac_murinae_reindex_protein_92',
           'mouse_ncrna_db' => 'mysql://ensro@mysql-ens-compara-prod-2:4522/muffato_murinae_ncrna_trees_92',
           'projection_db'  => 'mysql://ensro@mysql-ens-compara-prod-3:4523/carlac_alt_allele_import_92',
           'members_db'     => 'mysql://ensro@mysql-ens-compara-prod-2:4522/carlac_load_members_92',
        },

        # The target database
        'curr_rel_db'   => "mysql://ensadmin:" . $ENV{ENSADMIN_PSW} . '@mysql-ens-compara-prod-1:4485/ensembl_compara_92',

        # From these databases, only copy these tables
        'only_tables'       => {
           # Cannot be copied by populate_new_database because it doesn't contain the new mapping_session_ids yet
           'master_db'     => [qw(mapping_session)],
        },

        # These tables have a unique source. Content from other databases is ignored
        'exclusive_tables'  => {
            'mapping_session'       => 'master_db',
            'hmm_annot'             => 'family_db',
            'gene_member'           => 'members_db',
            'seq_member'            => 'members_db',
            'other_member_sequence' => 'members_db',
            'sequence'              => 'members_db',
            'exon_boundaries'       => 'members_db',
            'seq_member_projection_stable_id' => 'members_db',
            'seq_member_projection' => 'protein_db',
            'peptide_align_feature_%' => 'protein_db',
        },

        # In these databases, ignore these tables
        'ignored_tables'    => {
            # 'members_db' => [qw(gene transcript)],
            # 'protein_db'        => [qw(gene_tree_node)],
            # 'protein_db'        => [qw(all_cov_ortho poor_cov_ortho poor_cov_2 dubious_seqs)],
            #'family_db' => [qw(gene_member seq_member sequence tmp_job job_summary test_length)],
            # 'mouse_prot_db'  => [qw(prev_rel_gene_member prev_ortholog_goc_metric)],
            # 'mouse_ncrna_db' => [qw(prev_ortholog_goc_metric)],
        },

   };
}

1;
