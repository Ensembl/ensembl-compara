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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CalculateWGACoverage

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

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::CalculateWGACoverage;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

	Description: pull alignment from DB for each alignment method_link_species_set for the given ortholog dnafrags

=cut

sub fetch_input {
	my $self = shift;

	my %aln_ranges;
	my @orth_batch = @{ $self->param_required('orth_batch') };
        
	my $dba = $self->get_cached_compara_dba('pipeline_url');
	# if ( $self->param('alt_aln_db') ) { $dba = $self->get_cached_compara_dba('alt_aln_db'); }
	# else { $dba = $self->compara_dba }
	my $do_disconnect = $self->dbc && ($dba->dbc ne $self->dbc);
	
	my $mlss_adap       = $dba->get_MethodLinkSpeciesSetAdaptor;
	my $gblock_adap     = $dba->get_GenomicAlignBlockAdaptor;
	my $dnafrag_adaptor = $dba->get_DnaFragAdaptor;

	$self->db->dbc->disconnect_if_idle if $do_disconnect;

	foreach my $orth ( @orth_batch ) {
		my @orth_dnafrags = @{ $orth->{ 'orth_dnafrags'} };
		my @aln_mlss_ids  = @{ $self->param_required( 'aln_mlss_ids' ) };
		
		my $s1_dnafrag = $dnafrag_adaptor->fetch_by_dbID( $orth_dnafrags[0]->{id} );
		my $s2_dnafrag = $dnafrag_adaptor->fetch_by_dbID( $orth_dnafrags[1]->{id} );

		for my $aln_mlss_id ( @aln_mlss_ids ) {
                    my $aln_coords = $gblock_adap->_alignment_coordinates_on_regions($aln_mlss_id,
                        $orth_dnafrags[0]->{id}, $orth_dnafrags[0]->{start}, $orth_dnafrags[0]->{end},
                        $orth_dnafrags[1]->{id}, $orth_dnafrags[1]->{start}, $orth_dnafrags[1]->{end},
                    );

                    if ( scalar( @$aln_coords ) < 1 ) {
			$self->warning("No alignment found for homology_id " . $orth->{id});
                        $self->db->dbc->disconnect_if_idle if $do_disconnect;
			next;
                    }

                    foreach my $coord_pair (@$aln_coords) {
                        push @{ $aln_ranges{$orth->{'id'}}->{$aln_mlss_id}->{$s1_dnafrag->genome_db_id} }, [ $coord_pair->[0], $coord_pair->[1] ];
                        push @{ $aln_ranges{$orth->{'id'}}->{$aln_mlss_id}->{$s2_dnafrag->genome_db_id} }, [ $coord_pair->[2], $coord_pair->[3] ];
                    }
                }
	}
	
	# disconnect from compara_db
	$dba->dbc->disconnect_if_idle();

	$self->param( 'aln_ranges', \%aln_ranges );
}

=head2 run

	Description: calaculate wga_score based on ortholog ranges, exon ranges and genomic alignment coverage

=cut

sub run {
	my $self = shift;
	my $dba  = $self->get_cached_compara_dba('pipeline_url');
	my $gdba = $dba->get_GenomeDBAdaptor;

	my @orth_batch = @{ $self->param_required('orth_batch') };
	my %aln_ranges = %{ $self->param_required('aln_ranges') };

	my (@qual_summary, @orth_ids);
	foreach my $orth ( @orth_batch ) {
		my @orth_dnafrags = @{ $orth->{ 'orth_dnafrags'} };
		my $orth_ranges    = $orth->{ 'orth_ranges' };
		my $homo_id        = $orth->{'id'};
		my $this_aln_range = $aln_ranges{ $homo_id  };
		my $exon_ranges    = $orth->{ 'exons' };

		push( @orth_ids, $homo_id );

		next unless ( defined $this_aln_range ); 

		if ( defined $exon_ranges ){
			foreach my $aln_mlss ( keys %{ $this_aln_range } ){
				foreach my $gdb_id ( sort {$a <=> $b} keys %{ $orth_ranges } ){
					# Make sure that if this is a component gdb_id it refers back to the principal. The exon and ortholog data is on the components and not on the principal, but the aln_mlss is only on principal
					my $gdb = $gdba->fetch_by_dbID($gdb_id);
					my $principal_gdb = $gdb->principal_genome_db;
					my $principal_gdb_id = $principal_gdb ? $principal_gdb->dbID : $gdb_id;
					my $combined_coverage = $self->_combined_coverage( $orth_ranges->{$gdb_id}, $this_aln_range->{$aln_mlss}->{$principal_gdb_id}, $exon_ranges->{$gdb_id} );
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

=head2 write_output

    flow quality scores to the ortholog_quality table
    flow homology_ids to assign_quality analysis 

=cut

sub write_output {
	my $self = shift;

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
			next if ( $b_start > $p_end   );
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
			next if ( $e_start > $p_end   );
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
