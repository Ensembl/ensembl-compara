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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareAlignment

=head1 SYNOPSIS

	Fetch alignment blocks that connect the species of interest, format and dataflow

=head1 DESCRIPTION

	Inputs:
	orth_dnafrags	list of dnafrag_ids that cover each member of the homology
	orth_ranges		(only required for passthrough)
	orth_id			(only required for passthrough)
	orth_exons		(only required for passthrough)
	aln_mlss_ids	arrayref of method_link_species_set_ids for the alignment between these species
	alt_aln_db		by default, alignments are fetched from the compara_db parameter.
					to use a different source, define alt_aln_db with a URL to a DB containing alignments
	species1_id		genome_db_id of first species  |
	species2_id		genome_db_id of second species |-> these are only used to limit multiple alignment blocks

	Outputs:
	Dataflow fan: { 
			gblock_id => dbID, 
			gblock_range => [start,end],
			orth_ranges  => $self->param('orth_ranges'),
			orth_id      => $self->param('orth_id'),
			orth_exons   => $self->param('orth_exons'),
		}

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::PrepareAlignment;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

	Description: pull alignment from DB for each alignment method_link_species_set for the given ortholog dnafrags

=cut

sub fetch_input {
	my $self = shift;

        my ( $mlss_adap, $gblock_adap, $dnafrag_adaptor, $dba );

        if ( $self->param('alt_aln_db') ) { $dba = $self->get_cached_compara_dba('alt_aln_db'); }
        else { $dba = $self->compara_dba }

        $mlss_adap       = $dba->get_MethodLinkSpeciesSetAdaptor;
        $gblock_adap     = $dba->get_GenomicAlignBlockAdaptor;
        $dnafrag_adaptor = $dba->get_DnaFragAdaptor;

        $self->db->dbc->disconnect_if_idle;

	my %aln_ranges;
	my @orth_batch = @{ $self->param_required('orth_batch') };

	foreach my $orth ( @orth_batch ) {
		my @orth_dnafrags = @{ $orth->{ 'orth_dnafrags'} };
		my @aln_mlss_ids  = @{ $orth->{ 'aln_mlss_ids' } };

		my $s1_dnafrag = $dnafrag_adaptor->fetch_by_dbID( $orth_dnafrags[0]->{id} );
		my $s2_dnafrag = $dnafrag_adaptor->fetch_by_dbID( $orth_dnafrags[1]->{id} );

		my ($dnafrag_start, $dnafrag_end) = ( $orth_dnafrags[0]->{start}, $orth_dnafrags[0]->{end} );

		my @gblocks;
		for my $aln_mlss_id ( @aln_mlss_ids ) {
			my $mlss = $mlss_adap->fetch_by_dbID( $aln_mlss_id );
			my $these_gblocks = $gblock_adap->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag( $mlss, $s1_dnafrag, $dnafrag_start, $dnafrag_end, $s2_dnafrag );
			push( @gblocks, @{ $these_gblocks } );
		}

		if ( scalar( @gblocks ) < 1 ) {
			$self->input_job->autoflow(0);
			my $exit_msg = "No alignment found for this homology";
			$self->complete_early($exit_msg);
		}

	    foreach my $gblock ( @gblocks ) {
	    	my $gb_mlss = $gblock->method_link_species_set_id;
	    	foreach my $ga ( @{ $gblock->get_all_GenomicAligns } ) {
		        my $current_gdb = $ga->genome_db->dbID;
		        # limit multiple alignment blocks to only the species of interest
		        next unless ( $current_gdb == $self->param_required( 'species1_id' ) || $current_gdb == $self->param_required( 'species2_id' ) );
		        push( @{ $aln_ranges{$orth->{'id'}}->{$gb_mlss}->{$current_gdb} }, [ $ga->dnafrag_start, $ga->dnafrag_end] );
		    }
	    }
	}
	
	# disconnect from compara_db
	$dba->dbc->disconnect_if_idle();

	$self->param( 'aln_ranges', \%aln_ranges );
}

=head2 run

	Description: parse Bio::EnsEMBL::Compara::Homology objects to get start and end positions
	of genes

=cut

sub run {
	my $self = shift;	

	my @orth_batch = @{ $self->param_required('orth_batch') };
	my %aln_ranges = %{ $self->param_required('aln_ranges') };

	my (@qual_summary, @orth_ids);
	foreach my $orth ( @orth_batch ) {
		my @orth_dnafrags = @{ $orth->{ 'orth_dnafrags'} };
		my @aln_mlss_ids  = @{ $orth->{ 'aln_mlss_ids' } };

		my $orth_ranges = $orth->{ 'orth_ranges' };
		my $homo_id     = $orth->{'id'};
		my $aln_ranges  = $aln_ranges{ $homo_id  };
		my $exon_ranges = $orth->{ 'exons' };

		push( @orth_ids, $homo_id );

		unless ( defined $aln_ranges ) {
			$self->input_job->autoflow(0);
			my $exit_msg = "No alignment found for this homology";
			$self->complete_early($exit_msg);
		}

		if ( defined $exon_ranges ){
			foreach my $aln_mlss ( keys %{ $aln_ranges } ){
				foreach my $gdb_id ( sort {$a <=> $b} keys %{ $orth_ranges } ){
					my $combined_coverage = $self->_combined_coverage( $orth_ranges->{$gdb_id}, $aln_ranges->{$aln_mlss}->{$gdb_id}, $exon_ranges->{$gdb_id} );
					push( @qual_summary, 
						{ homology_id              => $homo_id, 
						  genome_db_id             => $gdb_id,
						  alignment_mlss		   => $aln_mlss,
						  combined_exon_coverage   => $combined_coverage->{exon},
						  combined_intron_coverage => $combined_coverage->{intron},
						  quality_score            => $combined_coverage->{score},
						  exon_length              => $combined_coverage->{exon_len},
						  intron_length            => $combined_coverage->{intron_len},
						} 
					);
				}
			}
		}

	}

	$self->param( 'orth_ids', \@orth_ids );
	$self->param('qual_summary', \@qual_summary);

}

# =head2 write_output

# 	Description: send data to correct dataflow branch!

# =cut

# sub write_output_prep_aln {
# 	my $self = shift;

# 	my $funnel_dataflow = {
# 		aln_ranges  => $self->param('aln_ranges'),
# 		orth_ranges => $self->param('orth_ranges'),
# 		orth_id     => $self->param('orth_id'),
# 		orth_exons  => $self->param('orth_exons'),
# 	};

# 	$self->dataflow_output_id( $funnel_dataflow, 1 ); # to combine_coverage
# 	# $self->dataflow_output_id( { orth_id => $self->param('orth_id') }, 1 ); # to assign_quality
# }

=head2 write_output

=cut

sub write_output {
	my $self = shift;

	# print "FLOWING #1: ";
	# print Dumper $self->param('qual_summary');
	# print "FLOWING #2: ";
	# print Dumper $self->param('wga_coverage');

	# flow data
	$self->dataflow_output_id( $self->param('qual_summary'), 1 );
	$self->dataflow_output_id( { orth_ids => $self->param( 'orth_ids' ) }, 2 ); # to assign_quality
}

=head2 _combined_coverage 

	For a given ortholog range, alignment ranges and exonic ranges, return a hash ref summarizing
	coverage of introns and exons

=cut

sub _combined_coverage {
	my ($self, $o_range, $a_ranges, $e_ranges) = @_;

	# split problem into smaller parts for memory efficiency
	my @parts = $self->_partition_ortholog( $o_range, 10 );

	my ($exon_tally, $intron_tally, $total, $exon_len) = (0,0,0,0);
	foreach my $part ( @parts ) {
		my ( $p_start, $p_end ) = @{ $part };
		# print "\n\n\np_start, p_end = ($p_start, $p_end)\n";
		# create alignment map
		my %alignment_map;
		foreach my $ar ( @{ $a_ranges } ) {
			my ( $b_start, $b_end ) = @{ $ar };
			# print "before.... b_start, b_end = ($b_start, $b_end)\n";

			# check alignment lies inside partition
			next if ( $b_end   < $p_start );
			last if ( $b_start > $p_end   );
			$b_start = $p_start if ( $b_start <= $p_start && ( $b_end >= $p_start && $b_end <= $b_end ) );
			$b_end = $p_end     if ( $b_end >= $p_end && ( $b_start >= $p_start && $b_start <= $b_end ) );

			# print "after..... b_start, b_end = ($b_start, $b_end)\n";

			foreach my $x ( $b_start..$b_end ) {
				$alignment_map{$x} = 1;
			}
		}

		# create exon map
		my %exon_map;
		foreach my $er ( @{ $e_ranges } ) {
			my ( $e_start, $e_end ) = @{ $er };
			# print "before.... e_start, e_end = ($e_start, $e_end)\n";

			# check exon lies inside partition
			next if ( $e_end   < $p_start );
			last if ( $e_start > $p_end   );
			$e_start = $p_start if ( $e_start <= $p_start && ( $e_end >= $p_start && $e_end <= $e_end ) );
			$e_end = $p_end     if ( $e_end >= $p_end && ( $e_start >= $p_start && $e_start <= $e_end ) );

			# print "after..... e_start, e_end = ($e_start, $e_end)\n";

			foreach my $x ( $e_start..$e_end ) {
				$exon_map{$x} = 1;
			}
		}

		$exon_len += scalar( keys %exon_map );

		# calculate coverage
		foreach my $x ( $p_start..$p_end ) {
			$total++;
			if ( $alignment_map{$x} ){
				if ( $exon_map{$x} ) { $exon_tally++; }
				else { $intron_tally++; }
			}
		}
	}

	my $intron_len = $total - $exon_len;

	my $e_cov = ($exon_len   > 0) ? ( $exon_tally/$exon_len     ) * 100 : 0;
	my $i_cov = ($intron_len > 0) ? ( $intron_tally/$intron_len ) * 100 : 0;

	my $score = $self->_quality_score( $exon_len, $intron_len, $e_cov, $i_cov );

	return { 
		'exon'       => $e_cov, 
		'intron'     => $i_cov, 
		'score'      => $score, 
		'exon_len'   => $exon_len,
		'intron_len' => $intron_len,
	};
}

=head2 _partition_ortholog

	- splits the range of an ortholog into a defined number of partitions ($no_parts)
	- returns an array of arrayrefs representing the start and end coordinates of each partition
	- used to cut down on memory usage, while still keeping the efficiency of a hash-map approach

=cut

sub _partition_ortholog {
	my ( $self, $o_range, $no_parts ) = @_;

	my ($o_start, $o_end) = @{ $o_range };
	( $o_end, $o_start ) = ( $o_start, $o_end ) if ( $o_start > $o_end ); # reverse
	my $o_len = $o_end - $o_start;

	my $step = int($o_len/$no_parts);
	my @parts;
	my $start = $o_start;
	foreach my $i ( 0..($no_parts-1) ) {
		push( @parts, [ $start, $start+$step ] );
		$start = $start+$step+1;
	}
	$parts[-1]->[1] = $o_end;
	return @parts;
}

=head2 _quality_score

	given exon and intron length and coverage, calculate a combined quality score

=cut

sub _quality_score {
	my ( $self, $el, $il, $ec, $ic ) = @_;

	my $exon_compl   = 100 - $ec;
	my $prop_introns = $il/($el + $il);

	my $score = $ec + ( $exon_compl * $prop_introns * ($ic/100) );
	$score = 100 if ( $score > 100 );

	return $score;
}

1;