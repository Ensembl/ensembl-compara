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

Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MergeDBsIntoRelease_conf

=head1 SYNOPSIS

    #1. update all databases' names and locations

    #2. initialize the pipeline:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MergeDBsIntoRelease_conf -host mysql-ens-compara-prod-X -port XXXX

    #3. run the beekeeper.pl

=head1 DESCRIPTION

A Vertebrates specific pipeline to merge some production databases onto the release one.
It is currently working well only with the "gene side" of Compara (protein_trees, families and ncrna_trees)
because synteny_region_id is not ranged by MLSS.

The default parameters work well in the context of a Compara release for Vertebrates (with a well-configured
Registry file). If the list of source-databases is different, have a look at the bottom of the base file
for alternative configurations.

Selected funnel analyses are blocked on pipeline initialisation.
These should be unblocked as needed during pipeline execution.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::MergeDBsIntoRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::MergeDBsIntoRelease_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},
        'division' => 'vertebrates',

        # All the source databases
        # edit the reg_conf file rather than adding URLs
        'src_db_aliases'    => {
            'master_db'      => 'compara_master',
            'protein_db'     => 'compara_ptrees',
            'ncrna_db'       => 'compara_nctrees',
            'mouse_prot_db'  => 'murinae_ptrees',
            'mouse_ncrna_db' => 'murinae_nctrees',
            'pig_prot_db'    => 'pig_breeds_ptrees',
            'pig_ncrna_db'   => 'pig_breeds_nctrees',
            'projection_db'  => 'alt_allele_projection',
            'members_db'     => 'compara_members',
        },

        # From these databases, only copy these tables
        'only_tables'       => {
           # Cannot be copied by populate_new_database because it doesn't contain the new mapping_session_ids yet
           'master_db'     => [qw(mapping_session)],
        },

        # These tables have a unique source. Content from other databases is ignored
        'exclusive_tables'  => {
            'mapping_session'       => 'master_db',
            'hmm_annot'             => 'protein_db',
            'gene_member'           => 'members_db',
            'seq_member'            => 'members_db',
            'other_member_sequence' => 'members_db',
            'sequence'              => 'members_db',
            'exon_boundaries'       => 'members_db',
            'seq_member_projection_stable_id' => 'members_db',
            'seq_member_projection' => 'protein_db',
            'peptide_align_feature%' => 'protein_db',
        },

        # In these databases, ignore these tables
        'ignored_tables' => {
            # Mapping 'db_alias' => Arrayref of table names
            'ncrna_db'       => [qw(ortholog_quality datacheck_results method_link_species_set_attr)],
            'protein_db'     => [qw(ortholog_quality datacheck_results)],
            'mouse_prot_db'  => [qw(ortholog_quality datacheck_results)],
            'mouse_ncrna_db' => [qw(ortholog_quality datacheck_results method_link_species_set_attr)],
            'pig_prot_db'    => [qw(ortholog_quality datacheck_results)],
            'pig_ncrna_db'   => [qw(ortholog_quality datacheck_results method_link_species_set_attr)],
        },
   };
}

sub tweak_analyses {
    my $self = shift;
    $self->SUPER::tweak_analyses(@_);
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
