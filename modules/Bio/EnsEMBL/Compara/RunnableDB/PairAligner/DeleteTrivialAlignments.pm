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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DeleteTrivialAlignments

=head1 DESCRIPTION

This Runnable is only useful for self-alignments. In those cases, LastZ generates trivial alignments
(i.e. a region against itself) and we need to delete them in order to keep only the duplications.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DeleteTrivialAlignments;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{ $self->SUPER::param_defaults() },

        # Force BaseRunnable::call_within_transaction() to use transactions to delete the rows
        'do_transactions'   => 1,
    };
}


sub fetch_input {
    my ($self) = @_;

    my $mlss_id = $self->param_required('method_link_species_set_id');
    if (scalar(@{ $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id)->species_set_obj->genome_dbs }) != 1) {
        $self->complete_early('Skipping DeleteTrivialAlignments as we are dealing with more than one species');
    }
}


sub run {
    my $self = shift;

    my $sql_fetch_blocks = 'SELECT genomic_align_block_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand FROM genomic_align WHERE method_link_species_set_id = ?';
    my $sth = $self->compara_dba->dbc->prepare($sql_fetch_blocks, { 'mysql_use_result' => 1 });
    $sth->execute($self->param('method_link_species_set_id'));
    warn "Query executed, now fetching the rows\n";

    # The genomic_align entries can be paired by genomic_align_block_id.
    # We buffer the output and find the pairs. We then compare the
    # dnafrag_* fields within each pair
    my @trivial_gab_ids = ();
    my %genomic_align_buffer = ();
    while (my $a = $sth->fetchrow_arrayref()) {
        my $gab_id = $a->[0];
        if (exists $genomic_align_buffer{$gab_id}) {
            my $b = delete $genomic_align_buffer{$gab_id};
            if (($a->[4] == $b->[4]) and ($a->[1] == $b->[1]) and ($a->[2] == $b->[2]) and ($a->[3] == $b->[3])) {
                push @trivial_gab_ids, $gab_id;
            }
        } else {
            # We need to make a copy of $a because DBD reuses the same internal array
            $genomic_align_buffer{$gab_id} = [@$a];
        }
    }
    warn scalar(@trivial_gab_ids), " trivial gab_ids found\n";
    $self->param('trivial_gab_ids', \@trivial_gab_ids);
}


sub write_output {
    my $self = shift;

    my $sql_delete_gab = 'DELETE FROM genomic_align_block WHERE genomic_align_block_id = ?';
    my $sql_delete_ga  = 'DELETE FROM genomic_align       WHERE genomic_align_block_id = ?';
    my $sth_delete_gab = $self->compara_dba->dbc->prepare($sql_delete_gab);
    my $sth_delete_ga  = $self->compara_dba->dbc->prepare($sql_delete_ga);

    foreach my $gab_id (@{$self->param('trivial_gab_ids')}) {
        warn "going to delete $gab_id\n";
        $self->call_within_transaction( sub {
            $sth_delete_ga->execute($gab_id);
            $sth_delete_gab->execute($gab_id);
        } );
    }
}

1;
