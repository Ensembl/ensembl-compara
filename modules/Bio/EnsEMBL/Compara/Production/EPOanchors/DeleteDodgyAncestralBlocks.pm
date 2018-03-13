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

Bio::EnsEMBL::Compara::Production::EPOanchors::DeleteDodgyAncestralBlocks

=head1 SYNOPSIS

Specialized version of Bio::EnsEMBL::Hive::RunnableDB::SqlCmd
that runs the query on the compara database.

=cut


package Bio::EnsEMBL::Compara::Production::EPOanchors::DeleteDodgyAncestralBlocks;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},

        # So far the problem has been limited to one or two blocks, and I
        # don't want to inadvertently delete the whole alignment !
        'max_blocks_to_delete'  => 2,
    };
}

sub fetch_input {
    my $self = shift;

    # Find the genome_db_id of ancestral_sequences
    my $ancestral_gdb_id = $self->compara_dba->dbc->sql_helper->execute_single_result(
        -SQL => 'SELECT genome_db_id FROM genome_db WHERE name = ?',
        -PARAMS => [ 'ancestral_sequences' ],
    );

    # Find the bad blocks
    my $sql = 'SELECT DISTINCT genomic_align_block_id FROM (SELECT genomic_align_block_id FROM genomic_align JOIN dnafrag USING (dnafrag_id) WHERE genome_db_id != ? AND method_link_species_set_id = ?) _t1 JOIN (SELECT genomic_align_block_id FROM genomic_align JOIN dnafrag USING (dnafrag_id) WHERE genome_db_id = ? AND method_link_species_set_id = ?) _t2 USING (genomic_align_block_id)';
    my $bad_gab_ids = $self->compara_dba->dbc->sql_helper->execute(
        -SQL => $sql,
        -PARAMS => [$ancestral_gdb_id, $self->param_required('mlss_id'), $ancestral_gdb_id, $self->param('mlss_id')],
    );
    $bad_gab_ids = [map {$_->[0]} @$bad_gab_ids];
    $self->param('bad_gab_ids', $bad_gab_ids);

    # We don't want to delete too many blocks
    if (scalar(@$bad_gab_ids) > $self->param_required('max_blocks_to_delete')) {
        die sprintf("Found %d blocks to delete, more than the maximum allowed %d: %s\n", scalar(@$bad_gab_ids), $self->param_required('max_blocks_to_delete'), join(",", @$bad_gab_ids));
    }
    $self->say_with_header("blocks to delete: ".join(",", @$bad_gab_ids));
}

sub write_output {
    my $self = shift;
    
    my @sqls = (
        'DELETE genomic_align_tree FROM genomic_align JOIN genomic_align_tree USING (node_id) WHERE genomic_align_block_id = ?',
        'DELETE genomic_align WHERE genomic_align_block_id = ?',
        'DELETE genomic_align_block WHERE genomic_align_block_id = ?',
        # NOTE: maybe we should clean up the ancestral dnafrags too ?
    );
    
    my $dbc = $self->compara_dba->dbc;
    $self->call_within_transaction( sub {
        foreach my $gab_id (@{$self->param('bad_gab_ids')}) {
            foreach my $sql (@sqls) {
                $dbc->do($sql, undef, $gab_id);
            }
        }
    });
}

1;
