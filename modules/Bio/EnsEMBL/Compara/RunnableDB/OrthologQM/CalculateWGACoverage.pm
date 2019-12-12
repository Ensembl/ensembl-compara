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

Calculate wga_coverage scores for a set of orthologs. Scores are written to the `ortholog_quality`
table.

=head1 DESCRIPTION

    Inputs:
    species1_id     genome_db_id of first species
    species2_id     genome_db_id of second species
    orth_info       list of ortholog information. should contain hashrefs containing the following info:
                    {id => $homology_id, gene_members => [[gene_member_id_1, genome_db_id_1], [gene_member_id_2, genome_db_id_2]]}
    alignment_db    arrayref of method_link_species_set_ids for the alignment between these species
    aln_mlss_ids    arrayref of alignment mlss_ids linking these species
    alt_homology_db by default, homology seq_member information is fetched from the compara_db parameter.
                    to use a different source, define alt_homology_db with a URL or alias

    Outputs:
    Dataflow to ortholog_quality table:
        {
            homology_id              => $homology_id,
            genome_db_id             => $gdb_id,
            alignment_mlss           => $aln_mlss,
            combined_exon_coverage   => $combined_coverage->{exon},
            combined_intron_coverage => $combined_coverage->{intron},
            quality_score            => $combined_coverage->{score},
            exon_length              => $combined_coverage->{exon_len},
            intron_length            => $combined_coverage->{intron_len},
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

    # fetch additional homology info
    my $hom_dba = $self->param('alt_homology_db') ? $self->get_cached_compara_dba('alt_homology_db') : $self->compara_dba;
    $self->_load_member_info($hom_dba);
    $self->_load_exon_boundaries($hom_dba);

    # disconnect from homology_dba
    $hom_dba->dbc->disconnect_if_idle();

    # fetch alignment info
    my %aln_ranges;
    my @orth_info = @{ $self->param_required('orth_info') };

	my $dba = $self->get_cached_compara_dba('alignment_db');
	my $do_disconnect = $self->dbc && ($dba->dbc ne $self->dbc);

	my $mlss_adap       = $dba->get_MethodLinkSpeciesSetAdaptor;
	my $gblock_adap     = $dba->get_GenomicAlignBlockAdaptor;
	my $dnafrag_adaptor = $dba->get_DnaFragAdaptor;

	$self->db->dbc->disconnect_if_idle if $do_disconnect;

	foreach my $orth ( @orth_info ) {
        my ($orth_dnafrags, $orth_ranges) = $self->_orth_dnafrags($orth);
		my @aln_mlss_ids  = @{ $self->param_required( 'aln_mlss_ids' ) };

		my $s1_dnafrag = $dnafrag_adaptor->fetch_by_dbID( $orth_dnafrags->[0]->{id} );
		my $s2_dnafrag = $dnafrag_adaptor->fetch_by_dbID( $orth_dnafrags->[1]->{id} );

		for my $aln_mlss_id ( @aln_mlss_ids ) {
                    my $aln_coords = $gblock_adap->_alignment_coordinates_on_regions($aln_mlss_id,
                        $orth_dnafrags->[0]->{id}, $orth_dnafrags->[0]->{start}, $orth_dnafrags->[0]->{end},
                        $orth_dnafrags->[1]->{id}, $orth_dnafrags->[1]->{start}, $orth_dnafrags->[1]->{end},
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

	# disconnect from alignment_db
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

	my @orth_info  = @{ $self->param('orth_info') };
	my %aln_ranges = %{ $self->param('aln_ranges') };

	my (@qual_summary, @orth_ids);

	foreach my $orth ( @orth_info ) {
        my ($orth_dnafrags, $orth_ranges) = $self->_orth_dnafrags($orth);
		my @aln_mlss_ids  = @{ $self->param_required( 'aln_mlss_ids' ) };
		my $homo_id        = $orth->{'id'};
		my $this_aln_range = $aln_ranges{ $homo_id  };
        my $exon_ranges    = $self->_get_exon_ranges_for_orth($orth);

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
	$self->dataflow_output_id( $self->param('qual_summary'), 3 );
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

sub _load_exon_boundaries {
    my ( $self, $dba ) = @_;

    my $species1_id = $self->param_required('species1_id');
    my $species2_id = $self->param_required('species2_id');

    # Preload the exon boundaries for the whole genomes even though some of the members will be reused
    my $sql = 'SELECT gene_member_id, eb.dnafrag_start, eb.dnafrag_end FROM exon_boundaries eb JOIN gene_member USING (gene_member_id) WHERE genome_db_id IN (?,?)';
    my %exon_boundaries;
    my $sth = $dba->dbc->prepare($sql);
    $sth->execute($species1_id, $species2_id);
    while (my $row = $sth->fetchrow_arrayref()) {
        my ($gene_member_id, $dnafrag_start, $dnafrag_end) = @$row;
        push @{ $exon_boundaries{$gene_member_id} }, [$dnafrag_start, $dnafrag_end];
    }
    $sth->finish;
    $self->param('exon_boundaries', \%exon_boundaries);
}

sub _get_exon_ranges_for_orth {
    my ( $self, $orth ) = @_;

    my $exon_boundaries = $self->param('exon_boundaries');
    my $gene_members = $orth->{'gene_members'};
    my %orth_exons;
    foreach my $member_info ( @$gene_members ) {
        my ( $gm_id, $gdb_id ) = @$member_info;
        $orth_exons{$gdb_id} = $exon_boundaries->{$gm_id};
    }
    return \%orth_exons;
}

=head2 _load_member_info

Load info for seq_members and gene_members that are members of a homology
- gene_member.dnafrag_id, gene_member.dnafrag_start, gene_member.dnafrag_end
Store it in a param 'member_info'

=cut

sub _load_member_info {
    my ($self, $dba) = @_;

    my $gm_sql = 'SELECT dnafrag_id, dnafrag_start, dnafrag_end FROM gene_member WHERE gene_member_id = ?';
    my $gm_sth = $dba->dbc->prepare($gm_sql);

    my $homologies = $self->param('orth_info');
    my $member_info;
    foreach my $hom ( @$homologies ) {
        my ( $gm_id_1, $gm_id_2 ) = ( $hom->{gene_members}->[0]->[0], $hom->{gene_members}->[1]->[0] );

        $gm_sth->execute($gm_id_1);
        $member_info->{"gene_member_$gm_id_1"} = $gm_sth->fetchrow_hashref;
        $gm_sth->execute($gm_id_2);
        $member_info->{"gene_member_$gm_id_2"} = $gm_sth->fetchrow_hashref;
    }

    $self->param('member_info', $member_info);
}

sub _orth_dnafrags {
    my ( $self, $orth ) = @_;

    my $member_info  = $self->param('member_info');
    my $gene_members = $orth->{'gene_members'};
    my (%orth_ranges, @orth_dnafrags);
    foreach my $gm ( @$gene_members ) {
        my ( $gm_id, $gdb_id ) = @$gm;
        push( @orth_dnafrags, {
            id => $member_info->{"gene_member_$gm_id"}->{dnafrag_id},
            start => $member_info->{"gene_member_$gm_id"}->{dnafrag_start},
            end => $member_info->{"gene_member_$gm_id"}->{dnafrag_end}
        } );
        $orth_ranges{$gdb_id} = [ $member_info->{"gene_member_$gm_id"}->{dnafrag_start}, $member_info->{"gene_member_$gm_id"}->{dnafrag_end} ];
    }

    return ( \@orth_dnafrags, \%orth_ranges );
}

1;
