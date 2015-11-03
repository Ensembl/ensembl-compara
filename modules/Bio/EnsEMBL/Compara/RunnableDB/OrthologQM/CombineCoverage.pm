=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Report

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CombineCoverage;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;

=head2 fetch_input


=cut

sub fetch_input {
	
}

=head2 run

	Description: parse Bio::EnsEMBL::Compara::Homology objects to get start and end positions
	of genes

=cut

sub run {
	my $self = shift;	

	# my $quality_threshold = $self->param_required( 'quality_threshold' );
	my $orth_ranges = $self->param_required( 'orth_ranges' );
	my $aln_ranges  = $self->_format_aln_range( $self->param_required( 'aln_ranges' ) );

	my $exon_ranges = $self->param( 'orth_exon_ranges' );
	my $homo_id     = $self->param( 'orth_id' );

	my $m = 0;
	my ($combined_coverage, @qual_summary);
	if ( defined $exon_ranges ){
		foreach my $gdb_id ( keys %{ $orth_ranges } ){
			$combined_coverage = $self->_combined_coverage( $orth_ranges->{$gdb_id}, $aln_ranges->{$gdb_id}, $exon_ranges->{$gdb_id} );
			print "combined_coverage: ";
			print Dumper $combined_coverage;
			push( @qual_summary, 
				{ homology_id              => $homo_id, 
				  genome_db_id             => $gdb_id, 
				  combined_exon_coverage   => $combined_coverage->{exon},
				  combined_intron_coverage => $combined_coverage->{intron},
				  quality_score            => $m 
				} 
			);
		}
	}
	else {
		@qual_summary = ();
	}

	$self->param('qual_summary', \@qual_summary);
}

=head2 write_output

	Description: send data to correct dataflow branch!

=cut

sub write_output {
	my $self = shift;

	# flow data
	print "QUALITY SUMMARY: ";
	print Dumper $self->param( 'qual_summary' );
	$self->dataflow_output_id( $self->param('qual_summary'), 1 );
}

=head2 _combined_coverage 

	Take coverage data for each ortholog, sum and return hash ref

=cut

sub _combined_coverage {
	my ($self, $o_range, $a_range, $e_ranges) = @_;

	print "A_RANGE: ";
	print Dumper $a_range;

	# create alignment map
	my %alignment_map;
	foreach my $ar ( @{ $a_range } ) {
		my ( $b_start, $b_end ) = @{ $ar };
		print "\n\n!!!!! Looping alignment from $b_start to $b_end\n";
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

	# calculate coverage
	my ($exon_tally, $intron_tally, $total);
	my ($o_start, $o_end) = @{ $o_range };
	print "\n\n!!!!! Looping orth from $o_start to $o_end\n";
	foreach my $x ( $o_start..$o_end ) {
		$total++;
		if ( $alignment_map{$x} ){
			if ( $exon_map{$x} ) { $exon_tally++; }
			else { $intron_tally++; }
		}
	}

	my $e_cov = ( $exon_tally/$total   ) * 100;
	my $i_cov = ( $intron_tally/$total ) * 100;
	return { 'exon' => $e_cov, 'intron' => $i_cov };
}

sub _format_aln_range {
	my ( $self, $aln_ranges ) = @_;

	my %a_ranges;
	foreach my $block ( values %{ $aln_ranges } ) {
		foreach my $gdb_id ( keys %{ $block } ) {
			push( @{ $a_ranges{$gdb_id} }, $block->{$gdb_id});
		}
	}

	return \%a_ranges;
}

1;