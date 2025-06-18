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

Bio::EnsEMBL::Compara::PipeConfig::Metazoa::MergeDBsIntoRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Metazoa::MergeDBsIntoRelease_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

A Metazoa specific pipeline to merge some production databases onto the release one.
It is currently working well only with the "gene side" of Compara (protein_trees, families and ncrna_trees)
because synteny_region_id is not ranged by MLSS.

The default parameters work well in the context of a Compara release for Metazoa (with a well-configured
Registry file). If the list of source-databases is different, have a look at the bottom of the base file
for alternative configurations.

Selected funnel analyses are blocked on pipeline initialisation.
These should be unblocked as needed during pipeline execution.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Metazoa::MergeDBsIntoRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::MergeDBsIntoRelease_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        'division' => 'metazoa',

        # All the source databases
        # edit the reg_conf file rather than adding URLs
        'src_db_aliases'    => {
            'master_db'                 => 'compara_master',
            'default_protein_db'        => 'compara_ptrees',
            'protostomes_protein_db'    => 'protostomes_ptrees',
            'insects_protein_db'        => 'insects_ptrees',
            'drosophila_protein_db'     => 'drosophila_ptrees',
            'members_db'                => 'compara_members',
        },

        # From these databases, only copy these tables
        'only_tables'       => {
           # Cannot be copied by populate_new_database because it doesn't contain the new mapping_session_ids yet
           'master_db'     => [qw(mapping_session)],
        },

        # These tables have a unique source. Content from other databases is ignored
        'exclusive_tables'  => {
            'mapping_session'                   => 'master_db',
            'gene_member'                       => 'members_db',
            'seq_member'                        => 'members_db',
            'other_member_sequence'             => 'members_db',
            'sequence'                          => 'members_db',
            'exon_boundaries'                   => 'members_db',
        },

        # In these databases, ignore these tables
        'ignored_tables' => {
            # Mapping 'db_alias' => Arrayref of table names
            'members_db'                => [qw(hmm_annot)],
            'default_protein_db'        => [qw(ortholog_quality datacheck_results)],
            'protostomes_protein_db'    => [qw(ortholog_quality datacheck_results)],
            'insects_protein_db'        => [qw(ortholog_quality datacheck_results)],
            'drosophila_protein_db'     => [qw(ortholog_quality datacheck_results)],
        },

        'per_mlss_merge_tables' => [
            'hmm_annot',
            'homology',
            'homology_member',
            'method_link_species_set_attr',
            'method_link_species_set_tag',
            'peptide_align_feature',
        ],
    }
}

sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    # Block unguarded funnel analyses; to be unblocked as needed during pipeline execution.
    my @unguarded_funnel_analyses = (
        'fire_post_merge_processing',
        'enable_keys',
    );

    foreach my $logic_name (@unguarded_funnel_analyses) {
        $analyses_by_name->{$logic_name}->{'-analysis_capacity'} = 0;
    }

}

1;
