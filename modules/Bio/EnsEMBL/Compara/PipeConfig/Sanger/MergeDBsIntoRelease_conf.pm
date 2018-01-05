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

Bio::EnsEMBL::Compara::PipeConfig::Sanger::MergeDBsIntoRelease_conf

=head1 SYNOPSIS

    #1. update all databases' names and locations

    #2. initialize the pipeline:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Sanger::MergeDBsIntoRelease_conf -password <your_password>

    #3. run the beekeeper.pl

=head1 DESCRIPTION

A pipeline to merge some production databases onto the release one.
It is currently working well only with the "gene side" of Compara (protein_trees, families and ncrna_trees)
because synteny_region_id is not ranged by MLSS.

The default paramters work well in the context of an Ensembl Compara release (with a well-configured
Registry file). If the list of source-databases is different, have a look at the bottom of the base file
for alternative configurations.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Sanger::MergeDBsIntoRelease_conf;

use strict;
use warnings;

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
            'mouse_strains' => 'compara_mouse_strains_homologies',
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
            'hmm_annot'         => 'family_db',
            'gene_member'       => 'mouse_strains',
            'seq_member'        => 'mouse_strains',
            'other_member_sequence' => 'mouse_strains',
            'sequence'          => 'mouse_strains',
            'exon_boundaries'   => 'mouse_strains',
        },

        # In these databases, ignore these tables
        'ignored_tables'    => {
            #'protein_db'        => [qw(gene_tree_node)],
            #'protein_db'        => [qw(peptide_align_feature%)],
            #'family_db' => [qw(gene_member seq_member sequence tmp_job job_summary test_length)],
        },

   };
}

1;
