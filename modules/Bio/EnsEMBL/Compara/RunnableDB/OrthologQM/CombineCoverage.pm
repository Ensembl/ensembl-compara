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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CombineCoverage

=head1 SYNOPSIS

	Calculate % alignment coverage over both exons and introns in the homologs

=head1 DESCRIPTION

	Inputs:
	orth_ranges		should be hash ref with genome_db_id as key and value of array ref [start, end] positions
	orth_id			dbID of homology object in question
	aln_ranges		hash ref defining range of all gblocks hitting the homolog e.g. { gblock1 => { gdb1 => [1,100], gdb2 => [401,450] }, gblock2 => { gdb1 => [801,900], gdb2 => [451,500] } }
	orth_exons		hash ref defining start/end of all exonic regions e.g. { 123 => [[1,1000]], 150 => [[1,500], [800,900]] }

	From these inputs, the coverage for both members of the homology (exon & intron cov) will be calculated
	A score combining this information will also be computed

	Outputs:
	2 dataflows come from this runnable:
	#1: summary of exon and intron coverage & lens for each member of the homology
	#2: homology ID and final (averaged) score to write to homology table

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CombineCoverage;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input


=cut

sub fetch_input {
	
}

=head2 run

	Description: calculate coverage for both members of the homology

=cut

sub run {
	my $self = shift;	

	my $orth_ranges = $self->param_required( 'orth_ranges' );
	my $aln_ranges  = $self->param( 'aln_ranges' );
	my $homo_id     = $self->param( 'orth_id' );
	my $exon_ranges = $self->param_required('orth_exons');

	unless ( defined $aln_ranges ) {
		$self->input_job->autoflow(0);
		my $exit_msg = "No alignment found for this homology";
		$self->complete_early($exit_msg);
	}

	my ($combined_coverage, @qual_summary, %scores);
	if ( defined $exon_ranges ){
		foreach my $aln_mlss ( sort keys %{ $aln_ranges } ){
			foreach my $gdb_id ( sort {$a <=> $b} keys %{ $orth_ranges } ){
				$combined_coverage = $self->_combined_coverage( $orth_ranges->{$gdb_id}, $aln_ranges->{$aln_mlss}->{$gdb_id}, $exon_ranges->{$gdb_id} );
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
				push( @{ $scores{$aln_mlss} }, $combined_coverage->{score} );
			}
		}
	}
	else {
		@qual_summary = ();
	}

	$self->param('qual_summary', \@qual_summary);

	#$self->param('wga_coverage', { homology_id => $homo_id, wga_coverage => $self->_wga_coverage(\%scores) } );
}

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
	$self->dataflow_output_id( { orth_id => $self->param( 'orth_id' ) }, 2 ); # to assign_quality
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

sub _combined_coverage_old {
	my ($self, $o_range, $a_range, $e_ranges) = @_;

	# create alignment map
	my %alignment_map;
	foreach my $ar ( @{ $a_range } ) {
		my ( $b_start, $b_end ) = @{ $ar };
		foreach my $x ( $b_start..$b_end ) {
			$alignment_map{$x} = 1;
		}
	}

	# create exon map
	my %exon_map;
	foreach my $er ( @{ $e_ranges } ) {
		my ( $e_start, $e_end ) = @{ $er };
		foreach my $x ( $e_start..$e_end ) {
			$exon_map{$x} = 1;
		}
	}

	my $exon_len = scalar( keys %exon_map );

	# calculate coverage
	my ($exon_tally, $intron_tally, $total) = (0,0,0);
	my ($o_start, $o_end) = @{ $o_range };
	foreach my $x ( $o_start..$o_end ) {
		$total++;
		if ( $alignment_map{$x} ){
			if ( $exon_map{$x} ) { $exon_tally++; }
			else { $intron_tally++; }
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

# sub _format_aln_range {
# 	my ( $self, $aln_ranges ) = @_;

# 	my %a_ranges;
# 	foreach my $block ( values %{ $aln_ranges } ) {
# 		foreach my $gdb_id ( keys %{ $block } ) {
# 			push( @{ $a_ranges{$gdb_id} }, $block->{$gdb_id} );
# 		}
# 	}

# 	return \%a_ranges;
# }

# { mlss1 => [1,2,3,4], mlss2 => [5,6,7,8] }

# sub _wga_coverage {
# 	my ( $self, $scores ) = @_;

# 	return 0 unless (defined $scores);

# 	my @averages = sort { $a <=> $b } map { ($_->[0] + $_->[1])/2 } values %{ $scores };
# 	return $averages[-1]; # return max
# }

1;
