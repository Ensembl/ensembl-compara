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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MoveComponentGenes

=head1 DESCRIPTION

Moves genes between the dnafrags of two species. This is in practice
used for polyploid genomes and their components.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MoveComponentGenes;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'sqls'   => [
            'UPDATE dnafrag d1 JOIN gene_member gm USING (dnafrag_id) JOIN dnafrag d2 USING (name) SET gm.genome_db_id = #target_gdb_id#, gm.dnafrag_id = d2.dnafrag_id WHERE gm.genome_db_id = #source_gdb_id# AND d2.genome_db_id = #target_gdb_id#',
            'UPDATE dnafrag d1 JOIN  seq_member sm USING (dnafrag_id) JOIN dnafrag d2 USING (name) SET sm.genome_db_id = #target_gdb_id#, sm.dnafrag_id = d2.dnafrag_id WHERE sm.genome_db_id = #source_gdb_id# AND d2.genome_db_id = #target_gdb_id#',
        ],
    };
}

sub run {
    my $self = shift @_;

    # Quite a big transaction ahead. Make sure hive_capacity is set to 1 to avoid timeout on other threads !
    $self->call_within_transaction( sub {
        foreach my $s (@{$self->param('sqls')}) {
            $self->compara_dba->dbc->db_handle->do($s);
        }

        # genome_db_id is also used in species_tree_node, which is linked from
        #  -> gene_tree_node_attr : species_tree_node_id (taxon level of a gene tree node)
        #  -> gene_tree_node_tag : tag=lost_species_tree_node_id (taxon level of a missing gene in a gene tree)
        #  -> homology : species_tree_node_id (taxon level of paralogues / orthologues / homoeologues(
        #  -> species_tree_node_tag ? the stats (gene count, coverage, etc) for each genome
        # We're not renaming any of those because we want to keep the
        # initial taxonomy information

        # Finally, species_set and method_link_species_set also link to genome_db
        # They will be set-up correctly in OrthoTree directly, so no need
        # to change them here.
    } );
}

1;
