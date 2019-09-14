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

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::CalculateBlockStats

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::CalculateBlockStats;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::Cigars;
use Bio::EnsEMBL::Compara::Utils::Preloader;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift @_;

    $self->param('depth_by_genome', {});
    $self->param('total_pairwise_coverage', {});

    foreach my $genomic_align_block_id (@{$self->param_required('_range_list')}) {
        $self->process_one_block($genomic_align_block_id);
    }
}


sub process_one_block {
    my $self = shift @_;
    my $genomic_align_block_id = shift @_;

    my $genomic_align_block = $self->compara_dba->get_GenomicAlignBlockAdaptor->fetch_by_dbID($genomic_align_block_id);
    my $genomic_aligns      = $genomic_align_block->genomic_align_array();

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags($self->compara_dba->get_DnaFragAdaptor, $genomic_aligns);

    $self->disconnect_from_databases;

    my @all_cigar_arrays;
    my @all_genome_db_ids;
    my %cigar_lines_by_genome_db_id;
    while(my $ga = shift @$genomic_aligns) {
        my $genome_db_id    = $ga->dnafrag->genome_db_id;
        my $cigar_array     = Bio::EnsEMBL::Compara::Utils::Cigars::get_cigar_array($ga->cigar_line);

        push @all_cigar_arrays, $cigar_array;
        push @all_genome_db_ids, $genome_db_id;
        push @{$cigar_lines_by_genome_db_id{$genome_db_id}}, $cigar_array;
    }

    my $pairwise_coverage = $self->param('pairwise_coverage');
    my @gdbs = keys %cigar_lines_by_genome_db_id;
    while (my $gdb1 = shift @gdbs) {
        my $cigar_lines_1 = $cigar_lines_by_genome_db_id{$gdb1};
        foreach my $gdb2 (@gdbs) {
            my $cigar_lines_2 = $cigar_lines_by_genome_db_id{$gdb2};
            $pairwise_coverage->{$gdb1}->{$gdb2} += $self->_calculate_pairwise_coverage($cigar_lines_1, $cigar_lines_2);
            $pairwise_coverage->{$gdb2}->{$gdb1} += $self->_calculate_pairwise_coverage($cigar_lines_2, $cigar_lines_1);
        }
    }

    my $depth_by_genome = $self->param('depth_by_genome');
    my $depths = Bio::EnsEMBL::Compara::Utils::Cigars::compute_alignment_depth(\@all_cigar_arrays, \@all_genome_db_ids);
    foreach my $genome_db_id ( keys %$depths ) {
        foreach my $key (qw(n_total_pos depth_sum)) {
            $depth_by_genome->{$genome_db_id}->{$key} += $depths->{$genome_db_id}->{$key};
        }
    }
}

sub write_output {
    my $self = shift @_;

    my $depth_by_genome = $self->param('depth_by_genome');
    foreach my $genome_db_id ( keys %$depth_by_genome ) {
        my $n_total_pos         = $depth_by_genome->{$genome_db_id}->{'n_total_pos'};
        my $sum_aligned_bases   = $depth_by_genome->{$genome_db_id}->{'depth_sum'};
        $self->dataflow_output_id({'genome_db_id' => $genome_db_id, 'num_of_aligned_positions' => $n_total_pos}, 2);
        $self->dataflow_output_id({'genome_db_id' => $genome_db_id, 'sum_aligned_seq' => $sum_aligned_bases}, 3);
    }

    my $pairwise_coverage = $self->param('total_pairwise_coverage');
    foreach my $gdb1 ( keys %$pairwise_coverage ) {
        foreach my $gdb2 ( keys %{$pairwise_coverage->{$gdb1}} ) {
            $self->dataflow_output_id({
                    'from_genome_db_id'         => $gdb1,
                    'to_genome_db_id'           => $gdb2,
                    'num_of_aligned_positions'  => $pairwise_coverage->{$gdb1}->{$gdb2},
                }, 4);
        }
    }
}


sub _calculate_pairwise_coverage {
    my ($self, $cigar_lines_1, $cigar_lines_2) = @_;

    my $aligned_base_positions = 0;
    foreach my $from_cigar_line (@$cigar_lines_1) {
        #now we do the calculation of the aligned position. between the souce genomic align and the duplication genomic. A match for a single position can only be recorded once even if that position is matched in multiple duplicated genomic aligns
        my $cb = sub {
            my ($pos, $codes, $length) = @_;
            if (($codes->[0] eq 'M') && (scalar(grep {$_ eq 'M'} @$codes) >= 2)) {
                $aligned_base_positions += $length;
            }
        };
        Bio::EnsEMBL::Compara::Utils::Cigars::column_iterator([$from_cigar_line, @$cigar_lines_2], $cb, 'group');
    }
    return $aligned_base_positions;
}

1;
