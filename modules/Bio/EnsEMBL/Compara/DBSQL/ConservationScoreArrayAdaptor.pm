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

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::ConservationScoreArrayAdaptor

=head1 SYNOPSIS

  Connecting to the database using the Registry

     use Bio::EnsEMBL::Registry;
 
     my $reg = "Bio::EnsEMBL::Registry";

      $reg->load_registry_from_db(-host=>"ensembldb.ensembl.org", -user=>"anonymous");

      my $conservation_score_adaptor = $reg->get_adaptor(
         "Multi", "compara", "ConservationScore");

  Store data in the database

     $conservation_score_adaptor->store($conservation_score);

  To retrieve score data from the database using the default display_size
     $conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice);

  To retrieve one score per base in the slice
     $conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice, $slice->end-$slice->start+1);
  Print the scores
   foreach my $score (@$conservation_scores) {
      printf("position %d observed %.4f expected %.4f difference %.4f\n",  $score->position, $score->observed_score, $score->expected_score, $score->diff_score);
   }

  A simple example script for extracting scores from a slice can be found in ensembl-compara/scripts/examples/getConservationScores.pl

=head1 DESCRIPTION

Like ConservationScoreAdaptor, this adaptor can retrieve conservation scores from the database for a given region. The output format is however more direct. It is the array of the difference scores (expected minus observed).

The same data constraints are assumed: scores have to be stored in the database as LITTLE ENDIAN

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::DBSQL::ConservationScoreArrayAdaptor;

use strict;
use warnings;

use List::Util qw(min max);
use POSIX qw(floor);

use Set::IntervalTree;

use Bio::EnsEMBL::Compara::Locus;
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::Compara::Utils::Projection;

#store as 4 byte float. If change here, must also change in 
#ConservationScore.pm
my $_pack_size = 4;
my $_pack_type = 'f<';  # available since perl 5.10

use base qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 fetch_all_by_MethodLinkSpeciesSet_Locus

  Arg[1]      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
  Arg[2]      : Bio::EnsEMBL::Compara::Locus $locus
  Example     : $csa_adaptor->fetch_all_by_MethodLinkSpeciesSet_Locus($mlss, $locus);
  Description : Returns the (difference) conservation scores for the required region as
                an array of values (undef means no data). The strand of the locus is ignored
                and scores are always ordered in the array from the start coordinate to
                the end coordinate.
  Returntype  : Array-ref of floats
  Exceptions  : none
  Caller      : general

=cut

sub fetch_all_by_MethodLinkSpeciesSet_Locus {
    my ($self, $mlss, $locus) = @_;

    # Arrays to store the scores
    my @diff_scores;
    $#diff_scores = $locus->length;

    my $msa_mlss = $mlss->get_linked_mlss_by_tag('msa_mlss_id');

    $self->_fetch_and_add_scores_for_MethodLinkSpeciesSet_Locus(\@diff_scores, $msa_mlss, $locus, 0);

    return \@diff_scores;
}


=head2 fetch_all_by_MethodLinkSpeciesSet_Slice

  Arg[1]      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
  Arg[2]      : Bio::EnsEMBL::Slice $slice
  Example     : $csa_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice);
  Description : Returns the (difference) conservation scores for the required region as
                an array of values (undef means no data). The strand of the slice is ignored
                and scores are always ordered in the array from the start coordinate to
                the end coordinate.
  Returntype  : Array-ref of floats
  Exceptions  : none
  Caller      : general

=cut

sub fetch_all_by_MethodLinkSpeciesSet_Slice {
    my ($self, $mlss, $orig_slice) = @_;

    my @diff_scores;
    $#diff_scores = $orig_slice->length;
    my $msa_mlss             = $mlss->get_linked_mlss_by_tag('msa_mlss_id');

    my $projection_segments = Bio::EnsEMBL::Compara::Utils::Projection::project_Slice_to_reference_toplevel($orig_slice);

    foreach my $this_projection_segment (@$projection_segments) {

        my $slice = $this_projection_segment->to_Slice;
       
        #print $slice->seq_region_name . " " . $slice->start . " " . $slice->end . " offset=$offset\n";
        #warn "SEGMENT ".$slice->name()." ".$this_projection_segment->from_start."/".$this_projection_segment->from_end."\n";

        my $dnafrag = $self->db->get_DnaFragAdaptor->fetch_by_Slice($slice);
        my $locus = Bio::EnsEMBL::Compara::Locus->new(
                -DNAFRAG        => $dnafrag,
                -DNAFRAG_START  => $slice->seq_region_start,
                -DNAFRAG_END    => $slice->seq_region_end,
            );
        $self->_fetch_and_add_scores_for_MethodLinkSpeciesSet_Locus(\@diff_scores, $msa_mlss, $locus, $this_projection_segment->from_start() - 1);
    }

    return \@diff_scores;
}


## Internal methods - Data munging 
###################################


=head2 _fetch_and_add_scores_for_MethodLinkSpeciesSet_Locus

  Arg[1]      : Reference to an array big enough to hold all the scores $diff_scores
  Arg[2]      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
  Arg[3]      : Bio::EnsEMBL::Compara::Locus $locus
  Arg[4]      : Int $offset
  Example     : $csa_adaptor->_fetch_and_add_scores_for_MethodLinkSpeciesSet_Locus(\@diff_scores, $mlss, $locus, 0);
  Description : The crux of this module. This will fetch all the alignment and scores, extract matches and coordinates
                from the cigar-line and populate the $diff_scores array with the scores
  Returntype  : none
  Exceptions  : none
  Caller      : internal

=cut

sub _fetch_and_add_scores_for_MethodLinkSpeciesSet_Locus {
    my ($self, $diff_scores, $msa_mlss, $locus, $offset) = @_;

    my $light_genomic_aligns = $self->_get_all_ref_genomic_aligns($msa_mlss, $locus);

    $offset //= 0;

    my $locus_start = $locus->dnafrag_start;
    my $locus_end   = $locus->dnafrag_end;

    foreach my $light_genomic_align (@$light_genomic_aligns) {

        my $csa_objets = $self->_fetch_all_by_genomic_align_block_id_window_size($light_genomic_align->{genomic_align_block_id}, 1);

        my $score_intervals = Set::IntervalTree->new;
        $score_intervals->insert($_, $_->{align_start}, $_->{align_end}+1) for @$csa_objets;

        my $align_pos   = 1;
        my $direction   = $light_genomic_align->{dnafrag_strand} > 0 ? 1 : -1;
        my $genomic_pos = $direction > 0 ? $light_genomic_align->{dnafrag_start} : $light_genomic_align->{dnafrag_end};

        my $cigar_line = $light_genomic_align->{cigar_line};
        while ($cigar_line =~ /(\d*)([A-Za-z])/g) {
            my $char = $2;
            my $n = $1 || 1;
            if ($char eq 'M') {
                my $interval_start = $direction > 0 ? $genomic_pos : $genomic_pos-$n+1;
                my $interval_end   = $direction > 0 ? $genomic_pos+$n-1 : $genomic_pos;
                if (($interval_start <= $locus_end) and ($interval_end >= $locus_start)) {
                    foreach my $cs (@{$score_intervals->fetch($align_pos, $align_pos+$n)}) {
                        #warn "match at $genomic_pos/$align_pos for $n\n";
                        #warn "with scores at ".$cs->{align_start}."-".$cs->{align_end}."\n";
                        # Need to intersect both intervals
                        # The genomic-array index is $genomic_pos + $i - $locus_start
                        #  so $i must be >= $locus_start - $genomic_pos
                        #  so $i must be <= $locus_end   - $genomic_pos
                        # The score-array index is $align_pos + $i - $cs->{align_start}
                        #  so $i must be >= $cs->{align_start} - $align_pos
                        #  so $i must be <= $cs->{align_end} - $align_pos
                        my $first_i_genomic = $direction > 0 ? $locus_start - $genomic_pos : $genomic_pos - $locus_end;
                        my $last_i_genomic  = $direction > 0 ? $locus_end   - $genomic_pos : $genomic_pos - $locus_start;
                        my $first_i_score   = $cs->{align_start} - $align_pos;
                        my $last_i_score    = $cs->{align_end}   - $align_pos;
                        my $first_i         = max(0, $first_i_genomic, $first_i_score);
                        my $last_i          = min($n-1, $last_i_genomic, $last_i_score);
                        next if $first_i > $last_i;

                        my $genomic_index       = $genomic_pos + $direction * $first_i - $locus_start + $offset;
                        my $first_score_index   = $align_pos   + $first_i - $cs->{align_start};
                        my $last_score_index    = $align_pos   + $last_i  - $cs->{align_start};
                        #warn "first_i_genomic: $first_i_genomic, last_i_genomic: $last_i_genomic, first_i_score: $first_i_score, last_i_score: $last_i_score\n";
                        #warn "first_i: $first_i, last_i: $last_i, genomic_index: $genomic_index, score_index: $score_index\n";
                        unless ($cs->{diff_score_array}) {
                            $cs->{diff_score_array} = [unpack("$_pack_type*", $cs->{diff_score_str})];
                        }
                        foreach my $score (@{$cs->{diff_score_array}}[$first_score_index..$last_score_index]) {
                            if (($score != 0) and ((not defined $diff_scores->[$genomic_index]) or ($diff_scores->[$genomic_index] < $score))) {
                                $diff_scores->[$genomic_index] = $score;
                            }
                            $genomic_index += $direction;
                        }
                    }
                }
                $genomic_pos += $n * $direction;
                $align_pos += $n;

            } elsif ($char eq 'D') {
                $align_pos += $n;

            } elsif ($char eq 'I') {
                $genomic_pos += $n * $direction;

            } elsif ($char eq 'X') {
                $align_pos += $n;

            } else {
                die "Unknown cigar_line character: $char\n";
            }
        }
    }
}

sub _fetch_all_by_GenomicAlignBlock {
    my ($self, $genomic_align_block, $start, $end, $slice_length,
	$display_size, $display_type, $window_size) = @_;

   
    #default window size is the largest bucket that gives at least 
    #display_size values ie get speed but reasonable resolution
    my @window_sizes = (1, 10, 100, 500);

    #check if valid window_size
    my $found = 0;
    if (defined $window_size) {
	foreach my $win_size (@window_sizes) {
	    if ($win_size == $window_size) {
		$found = 1;
		last;
	    }
	}
	if (!$found) {
	    warning("Invalid window_size $window_size");
	}
    }
 
}


## Internal methods - Database access
######################################

=head2 _fetch_all_by_genomic_align_block_id_window_size

  Arg[1]      : Int $genomic_align_block_id
  Arg[2]      : Int $window_size
  Example     : $self->_fetch_all_by_genomic_align_block_id_window_size($genomic_align_block_id, $window_size);
  Description : Returns all the scores stored on a particular block, for a given window size. Each returned hash
                follows a simple structure to hold the scores and their position
  Returntype  : Array-ref of hashes
  Exceptions  : none
  Caller      : internal

=cut

sub _fetch_all_by_genomic_align_block_id_window_size {
    my ($self, $genomic_align_block_id, $window_size) = @_;

    my $sql = 'SELECT position, diff_score FROM conservation_score WHERE genomic_align_block_id = ? AND window_size = ?';
    my $sth = $self->prepare($sql);
    $sth->execute($genomic_align_block_id, $window_size);
    my ($position, $expected_score, $diff_score);
    $sth->bind_columns(\$position, \$diff_score);

    my @csa_objets;
    while (my $values = $sth->fetch()) {

        if (not defined $diff_score) {
            # Missing scores, just skip this row
            next;
        }
        my $length = CORE::length($diff_score) / $_pack_size;
        push @csa_objets, {
                #'genomic_align_block_id'    => $genomic_align_block_id,
                #'window_size'               => $window_size,
                'position'                  => $position,
                #'expected_score_str'        => $expected_score,
                'diff_score_str'            => $diff_score,
                #'length'                    => $length,
                'align_start'               => $position,
                'align_end'                 => $position+$length-1,
            };
    }
    $sth->finish;

    return \@csa_objets;
}


=head2 _get_all_ref_genomic_aligns

  Arg[1]      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
  Arg[2]      : Bio::EnsEMBL::Compara::Locus $locus
  Example     : $self->_get_all_ref_genomic_aligns($mlss, $locus);
  Description : Returns all the alignments stored on a particular region, for a given MLSS. Each returned hash
                follows a simple structure to hold the alignment and its position
  Returntype  : Array-ref of hashes
  Exceptions  : none
  Caller      : internal

=cut

sub _get_all_ref_genomic_aligns {
    my ($self, $mlss, $locus) = @_;

    my @light_genomic_aligns;

    my $max_alignment_length = $mlss->max_alignment_length;
    my $lower_bound = $locus->dnafrag_start - $max_alignment_length;

    my $sql = q{
          SELECT 
             genomic_align_block_id,
             dnafrag_start,
             dnafrag_end,
             dnafrag_strand,
             cigar_line
          FROM 
             genomic_align
          JOIN
             genomic_align_block
          USING
             (genomic_align_block_id)
          WHERE 
             genomic_align.method_link_species_set_id = ?
             AND dnafrag_id = ?
             AND dnafrag_start <= ?
             AND dnafrag_end >= ?
             AND dnafrag_start >= ?
           };

    my $sth = $self->prepare($sql);

    $sth->execute($mlss->dbID, $locus->dnafrag_id, $locus->dnafrag_end, $locus->dnafrag_start, $lower_bound);

    my ($genomic_align_block_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line);
    $sth->bind_columns(\$genomic_align_block_id, \$dnafrag_start, \$dnafrag_end, \$dnafrag_strand, \$cigar_line);

    while ($sth->fetch) {
        push @light_genomic_aligns, {
            genomic_align_block_id => $genomic_align_block_id,
            dnafrag_start => $dnafrag_start,
            dnafrag_end => $dnafrag_end,
            dnafrag_strand => $dnafrag_strand,
            cigar_line => $cigar_line,
        };

    }  
    $sth->finish;
    return \@light_genomic_aligns;
}


1;

