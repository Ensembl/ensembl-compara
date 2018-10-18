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

Bio::EnsEMBL::Compara::RunnableDB::MWGA_Stats_Summarizer

=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MWGAStatsSummarizer;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        #'aligned_bases_counter'     => {'148' => {'37' =>[3034,4003,1236,798,50]}},
        #'aligned_sequences_counter' => {'148' => [15726,1345, 7983,73649,63638]},
        #'aligned_positions_counter'	=> {'148' => [37464,8163,9173,52733,6382]},
    }
}

sub fetch_input {
    my $self = shift @_;
}

sub run {
	my $self = shift @_;
	foreach my $gdb_id (keys %{$self->param('aligned_bases_counter')}) {
		$self->_aligned_base_summarizer($gdb_id);
	}

	foreach my $gid (keys %{$self->param('aligned_sequences_counter')} ) {
		$self->dataflow_output_id({'genome_id' => $gid, 'aligned_seqs' => $self->param('aligned_sequences_counter')->{$gid}, 'aligned_positions' => $self->param('aligned_positions_counter')->{$gid}}, 2);
	}

}

sub _aligned_base_summarizer {
	my ($self, $from_gdbid) = @_;
	$self->dataflow_output_id({'from_genome_db_id' => $from_gdbid, 'pw_stats' => $self->param('aligned_bases_counter')->{$from_gdbid} }, 3);

}


1;
