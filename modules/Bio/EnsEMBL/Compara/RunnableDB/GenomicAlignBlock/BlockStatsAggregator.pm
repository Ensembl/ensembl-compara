=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::BlockStatsAggregator

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::BlockStatsAggregator;

use strict;
use warnings;

use List::Util qw(sum);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID( $self->param_required('mlss_id') );
    $self->param('node_hash', $mlss->species_tree->get_genome_db_id_2_node_hash());
}

sub run {
    my $self = shift @_;
    foreach my $gdb_id1 (keys %{$self->param('aligned_bases_counter')}) {
        my $node = $self->param('node_hash')->{$gdb_id1};
        foreach my $gdb_id2 (keys %{$self->param('aligned_bases_counter')->{$gdb_id1}}) {
            my $genome_coverage = sum( @{$self->param('aligned_bases_counter')->{$gdb_id1}->{$gdb_id2}} );
            $node->store_tag("genome_coverage_${gdb_id2}", $genome_coverage);
        }
    }

    foreach my $gdb_id (keys %{$self->param('aligned_sequences_counter')} ) {
        my $node                  = $self->param('node_hash')->{$gdb_id};
        my $sum_aligned_seqs      = sum(@{$self->param('aligned_sequences_counter')->{$gdb_id}});
        my $sum_aligned_positions = sum(@{$self->param('aligned_positions_counter')->{$gdb_id}});
        $node->store_tag('num_of_aligned_positions', $sum_aligned_positions);
        $node->store_tag('sum_aligned_seq',          $sum_aligned_seqs);
        $node->store_tag('genome_alignment_depth',   $sum_aligned_seqs / $sum_aligned_positions);
    }
}

1;
