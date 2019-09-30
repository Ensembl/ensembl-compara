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
    my $pairwise_coverage = $self->param_required('pairwise_coverage');
    foreach my $gdb_id1 (keys %$pairwise_coverage) {
        my $node = $self->param('node_hash')->{$gdb_id1};
        foreach my $gdb_id2 (keys %{$pairwise_coverage->{$gdb_id1}}) {
            my $genome_coverage = sum( @{$pairwise_coverage->{$gdb_id1}->{$gdb_id2}} );
            $node->store_tag("genome_coverage_${gdb_id2}", $genome_coverage);
        }
    }

    foreach my $gdb_id (keys %{$self->param('num_of_positions')} ) {
        my $node                        = $self->param('node_hash')->{$gdb_id};
        my $num_of_positions            = sum(@{$self->param('num_of_positions')->{$gdb_id}});
        my $num_of_aligned_positions    = sum(@{$self->param('num_of_aligned_positions')->{$gdb_id}});
        my $num_of_other_seq_positions  = sum(@{$self->param('num_of_other_seq_positions')->{$gdb_id}});

        $node->store_tag('num_of_positions',            $num_of_positions);
        $node->store_tag('num_of_aligned_positions',    $num_of_aligned_positions);
        $node->store_tag('num_of_other_seq_positions',  $num_of_other_seq_positions);
        $node->store_tag('average_depth',               $num_of_other_seq_positions / $num_of_positions);
        my $depth_breakdown = $self->param('depth_by_genome')->{$gdb_id};
        foreach my $depth (keys %$depth_breakdown) {
            my $s = sum(@{$depth_breakdown->{$depth}});
            $node->store_tag('num_positions_depth_'.$depth, $s);
        }
    }
}

1;
