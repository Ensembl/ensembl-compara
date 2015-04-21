=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor - Object adaptor to access data in the conservation_score table

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

This module is used to access data in the conservation_score table. The scores are stored in the database as LITTLE ENDIAN.
Each score is represented by a Bio::EnsEMBL::Compara::ConservationScore. The position and an observed, expected score and a difference score (expected-observed) is stored for each column in a multiple alignment. Not all columns in an alignment have a score (for example, if there is insufficient coverage) and termed here as 'uncalled'. 
In order to speed up processing of the scores over large regions, the scores are stored in the database averaged over window_sizes of 1 (no averaging), 10, 100 and 500. When retrieving the scores, the most appropriate window_size is estimated from the length of the alignment or slice and the number of scores requested, given by the display_size. There is no need to specify the window_size directly. If the number of scores requested (display_size) is smaller than the alignment length or slice length, the scores will be either averaged if display_type = "AVERAGE" or the maximum value taken if display_type = "MAX". Scores in uncalled regions are not returned. To return a score for each column in an alignment, the display_size should be set to be the same size as the alignment length or slice length. 

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor;

use vars qw(@ISA);
use strict;
use warnings;

use POSIX qw(floor);

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::ConservationScore;
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Config;

#global variables

#store as 4 byte float. If change here, must also change in 
#ConservationScore.pm
my $_pack_size = 4;
#my $_pack_type = "f<"; # not possible until perl 5.10. Avoid for now
my $_pack_type = "f";

my $_bucket; 
my $_score_index = 0;
#my $_no_score_value = 0.0; #value if no score
my $_no_score_value = undef; #value if no score

my $PACKED = 1;

#Check endian-ness. Always write data to database in LITTLE ENDIAN 
#Byteorders "1234" and "12345678" are little-endian; "4321" and "87654321" are big-endian.
my $is_little_endian = 1;
if ($Config{byteorder} eq "87654321" or $Config{byteorder} eq "4321") {
    $is_little_endian = 0;
}

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);



=head2 delete_by_genomic_align_block_id

  Arg  1     : int $genomic_align_block_id
  Example    : $conservation_score_adaptor->delete_by_genomic_align_block_id(123);
  Description: Delete all the scores related to this GenomicAlignBlock object
  Returntype : int (number of deleted rows, not scores)
  Exceptions : throw if not $genomic_align_block_id
  Status     : Stable

=cut

sub delete_by_genomic_align_block_id {
  my ($self, $genomic_align_block_id) = @_;

  unless (defined $genomic_align_block_id) {
    throw("Must define a genomic_align_block_id");
  }

  my $sql = "DELETE FROM conservation_score WHERE genomic_align_block_id = ?";
  my $sth = $self->prepare($sql);
  my $rv = $sth->execute($genomic_align_block_id);
  $sth->finish;

  return $rv;
}

=head2 fetch_all_by_MethodLinkSpeciesSet_Slice

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set 
  Arg  2     : Bio::EnsEMBL::Slice $slice
  Arg  3     : (opt) integer $display_size (default 700)
  Arg  4     : (opt) string $display_type (one of "AVERAGE" or "MAX") (default "AVERAGE")
  Arg  5     : (opt) integer $window_size
  Exceptions : warning if window_size is not valid
  Example    : my $conservation_scores =
                    $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice, $slice->end-$slice->start+1);
  Description: Retrieve the corresponding 
               Bio::EnsEMBL::Compara::ConservationScore objects. 
               Each conservation score object contains a position in slice 
               coordinates, the observed_score, the expected_score and the 
               diff_score (or conservation score) calculated as the 
               (expected_score - observed_score).
               The method_link_species_set is obtained
               using the method_link type of "GERP_CONSERVATION_SCORE". 
               For example, this could be obtained for the 10 way PECAN 
               alignment, using:
               my $mlss = $mlss_adaptor->fetch_by_method_link_type_registry_aliases("GERP_CONSERVATION_SCORE", ["human", "chimp", "rhesus", "cow", "dog", "mouse", "rat", "opossum", "platypus", "chicken"]);

               Display_size defines the number of scores that will be returned.
               To return a score for each column in an alignment the display_size 
               should be set to be the same size as the slice length eg ($slice->end-$slice->start+1).
               If the slice length is larger than the display_size, the scores 
               will either be averaged if the display_type is "AVERAGE" or the 
               maximum taken if display_type is "MAXIMUM". 
               Window_size defines which set of pre-averaged scores to use. 
               Valid values are 1, 10, 100 or 500 although there is no need to 
               define the window_size because the program will select the most 
               appropriate window_size to use based on the slice length and the
               display_size for example, a slice length of 1000000 and 
               display_size of 1000 will automatically use a window_size of 500.
               Slice positions which have no scores are not returned.
               The min and max y axis values for the array of 
               conservation score objects are set in the first conservation 
               score object (index 0). 

  Returntype : ref. to an array of Bio::EnsEMBL::Compara::ConservationScore objects. 
  Caller     : object::methodname
  Status     : At risk

=cut

sub fetch_all_by_MethodLinkSpeciesSet_Slice {
    my ($self, $method_link_species_set, $orig_slice, $display_size, $display_type, $window_size) = @_;

    my $scores = [];

    #need to convert conservation score mlss to the corresponding multiple 
    #alignment mlss

    my $ma_mlss_id = $method_link_species_set->get_value_for_tag('msa_mlss_id');
    my $ma_mlss;
    if ($ma_mlss_id) {
	$ma_mlss = $self->db->get_MethodLinkSpeciesSet->fetch_by_dbID($ma_mlss_id);
    } else {
	return $scores;
    }

    my $filter_projections = 1;
    my $projection_segments = $orig_slice->adaptor->fetch_normalized_slice_projection($orig_slice, $filter_projections);

    foreach my $this_projection_segment (@$projection_segments) {
        my $offset    = $this_projection_segment->from_start();

        my $these_scores = [];
        my $slice = $this_projection_segment->to_Slice;
        
        #print $slice->seq_region_name . " " . $slice->start . " " . $slice->end . " offset=$offset\n";

        my $light_genomic_aligns = $self->_get_all_ref_genomic_aligns($ma_mlss, $slice);
        
        if (scalar(@$light_genomic_aligns == 0)) {
            #print "no genomic_align_blocks found for this slice\n";
            #return $scores;
            next;
        }
        
        #default display_size is 700
        if (!defined $display_size) {
            $display_size = 700;
        }
        
        #default display_mode is AVERAGE
        if (!defined $display_type) {
            $display_type = "AVERAGE";
        }
        
        #set up bucket object for storing bucket_size number of scores 
        my $bucket_size = ($orig_slice->end-$orig_slice->start+1)/$display_size;
        
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
                return $scores;
            }
        }
    
        if (!defined $window_size) {
            #set window_size to be the largest for when for loop fails
            $window_size = $window_sizes[scalar(@window_sizes)-1];
            for (my $i = 1; $i < scalar(@window_sizes); $i++) {
                if ($bucket_size < $window_sizes[$i]) {
                    $window_size = $window_sizes[$i-1];
                    last;
                }
            }
        }

        #print "window_size $window_size bucket_size $bucket_size slice length " . ($slice->end - $slice->start + 1) . "\n";
        
        $_bucket = {diff_score => 0,
                    start_pos => 0,
                    end_pos => 0,
                    start_seq_region_pos => $slice->start,
                    end_seq_region_pos => $slice->end,
                    called => 0,
                    cnt => 0,
                    size => $bucket_size,
                    current => 0};
        foreach my $light_genomic_align (@$light_genomic_aligns) { 
            my $genomic_align_block_id = $light_genomic_align->{genomic_align_block_id};
            my $cigar_line = $light_genomic_align->{cigar_line};
            my $dnafrag_start = $light_genomic_align->{dnafrag_start};
            my $dnafrag_end = $light_genomic_align->{dnafrag_end};
            my $dnafrag_strand = $light_genomic_align->{dnafrag_strand};
            my $gab_length = $light_genomic_align->{length};
            
            my $conservation_scores = $self->_fetch_all_by_GenomicAlignBlockId_WindowSize($genomic_align_block_id, $window_size, $PACKED);
            if (scalar(@$conservation_scores) == 0) {
                next;
            }
            
            #reset _score_index for new conservation_scores
            $_score_index = 0;
            
            #print "slice start " . $slice->start . " " . $slice->end . " " . $slice->strand . " strand $dnafrag_strand cigar " . substr($cigar_line,0, 10) . "\n";
            
            #if dnafrag_strand is -1, reverse cigar_line, scores so that they 
            #are always on the forward strand
            if ($dnafrag_strand == -1) {
                
                $cigar_line = join("", reverse ($cigar_line=~(/(\d*[GDMIX])/g)));
                $conservation_scores = _reverse($conservation_scores, $gab_length);
                $dnafrag_strand = 1;
            }

            #print "after slice start " . $slice->start . " " . $slice->end . " " . $slice->strand . " strand $dnafrag_strand cigar " . substr($cigar_line,0, 10) . "\n";
            #if want one score per base in the alignment, use faster method 
            #doesn't bother with any binning
            if ($window_size == 1 && ($display_size == ($slice->end - $slice->start + 1))) {
                _get_aligned_scores_from_cigar_line_fast($self, $cigar_line, $dnafrag_start, $dnafrag_end, $slice->start, $slice->end, $conservation_scores, $genomic_align_block_id, $gab_length, $display_type, $these_scores);
            } else {
                _get_aligned_scores_from_cigar_line($self, $cigar_line, $dnafrag_start, $dnafrag_end, $slice->start, $slice->end, $conservation_scores, $genomic_align_block_id, $gab_length, $display_type, $window_size, $these_scores);
                
            } 
        }
        
        ## True if there are some values in the bucket that haven't been transformed into a score
        if ($_bucket->{called}) {

            my $genomic_align_block_id = $light_genomic_aligns->[-1]->{genomic_align_block_id};

            # This code is adapted from _get_aligned_scores_from_cigar_line
            # Again, we restore the values as they were before Kathryn's change in 2007
            my $prev_chr_pos = $_bucket->{start_seq_region_pos}+$_bucket->{cnt};

            for (my $i = $prev_chr_pos; $i <= $_bucket->{end_seq_region_pos}; $i+=$window_size) {
                my $aligned_score = _add_to_bucket($self, $display_type, $_no_score_value, $_no_score_value, $i, $slice->start, scalar(@$these_scores), $genomic_align_block_id, $window_size);
                if ($aligned_score) {
                    #need this to ensure that the aligned_scores array is the
                    #correct size (passed into _add_to_bucket)
                    push(@$these_scores, $aligned_score);
                }
            }
        }

        if (scalar(@$these_scores) == 0) {
            #return $scores;
            next;
        }
        
        #need to reverse scores
        if ($slice->strand == -1) {
            #reverse scores array
            @$these_scores = reverse(@$these_scores);
            #reverse positions
            foreach my $score (@$these_scores) {
                $score->position($slice->end - $score->seq_region_pos + 1);
            }
            #print "reverse scores\n";
        } 

        #Add offset to position
        if ($offset > 1) {
            foreach my $score (@$these_scores) {
                $score->position($score->position + $offset - 1);
            }
        }
        
        #remove _no_score_values from aligned_scores array
        my $i = 0;
        while ($i < scalar(@$these_scores)) {
            if (!defined($_no_score_value) && 
                !defined($these_scores->[$i]->diff_score)) {
                splice @$these_scores, $i, 1;
            } elsif (defined($_no_score_value) && 
                     $these_scores->[$i]->diff_score == $_no_score_value) {
                splice @$these_scores, $i, 1;
            } else {
                $i++;
            }
        }
        #foreach my $score (@$these_scores) {
        #    print "pos1 " . $score->position . " " . $score->diff_score . "\n";
        #}
        
        push @$scores, @$these_scores;
    }
    
    #Find the min and max scores for y axis scaling. Save in first
    #conservation score object
    my ($min_y_axis, $max_y_axis) =  _find_min_max_score($scores);
    
    #add min and max scores to the first conservation score object
    if ((scalar @$scores) > 0) {
	$scores->[0]->y_axis_min($min_y_axis);
	$scores->[0]->y_axis_max($max_y_axis);
    }

    return ($scores);
}

=head2 fetch_all_by_GenomicAlignBlock

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlignBlock $genomic_align_block
  Arg  2     : (opt) integer $align_start (default 1) 
  Arg  3     : (opt) integer $align_end (default $genomic_align_block->length)
  Arg  4     : (opt) integer $slice_length (default $genomic_align_block->length)
  Arg  5     : (opt) integer $display_size (default 700)
  Arg  6     : (opt) string $display_type (one of "AVERAGE" or "MAX") (default "AVERAGE")
  Arg  7     : (opt) integer $window_size
  Example    : my $conservation_scores =
                    $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock($genomic_align_block, $align_start, $align_end, $slice_length, $slice_length);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::ConservationScore objects. 
	       Each conservation score object contains a position in alignment
               coordinates, the observed_score, the expected_score and the 
               diff_score (conservation score) calculated as 
	       (expected_score - observed_score).
               The $align_start and $align_end parameters give the start and 
               end of a region within a genomic_align_block and should be in 
               alignment coordinates.
               The $slice_length is the total length of the region to be 
               displayed and may span several individual genomic align blocks.
               It is used to automatically calculate the window_size.
               Display_size is the number of scores that will be returned.
               To return a score for each column in an alignment the display_size 
               should be set to be the same size as the alignment length. If 
               the $slice_length is larger than the $display_size, the scores 
               will either be averaged if the display_type is "AVERAGE" or the 
               maximum taken if display_type is "MAXIMUM". 
	       Window_size defines which set of pre-averaged scores to use. 
	       Valid values are 1, 10, 100 or 500. There is no need to define 
               the window_size because the program will select the most 
               appropriate window_size to use based on the slice_length and the
               display_size. 
               Alignment positions which have no scores are not returned.
               The min and max y axis values for 
               the array of conservation score objects are set in the first 
               conservation score object (index 0). 
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::ConservationScore 
               objects. 
  Caller     : object::methodname
  Status     : At risk

=cut

sub fetch_all_by_GenomicAlignBlock {
    my ($self, $genomic_align_block, $start, $end, $slice_length,
	$display_size, $display_type, $window_size) = @_;

    #print "fetch_all_by_GenomicAlignBlock start $start end $end $display_size\n";

    #Check have either a GenomicAlignBlock or GenomicAlignTree object
    unless ($genomic_align_block && ref $genomic_align_block && 
            ($genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock") || 
             $genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignTree"))) {
        throw("genomic_align_block must be a Bio::EnsEMBL::Compara::GenomicAlignBlock or a Bio::EnsEMBL::Compara::GenomicAlignTree\n")
    }

    my $scores = [];

    #default display_size is 700
    if (!defined $display_size) {
	$display_size = 700;
    }

    #default display_mode is AVERAGE
    if (!defined $display_type) {
	$display_type = "AVERAGE";
    }

    #default start is 1
    if (!defined $start) {
	$start = 1;
    }

    #default end is the genomic_align_block length    
    if (!defined $end) {
	$end = $genomic_align_block->length;
    }

    #default slice_length is the genomic_align_block length
    if (!defined $slice_length) {
	$slice_length = $genomic_align_block->length;
    }

    #keep track of original start and end
    my $align_start = $start;
    my $align_end = $end;

    #If the GenomicAlignBlock has been restricted, use these values in 
    #align_start and align_end
    if (defined $genomic_align_block->{'_restricted_aln_start'}) {
	$align_start += $genomic_align_block->{'_restricted_aln_start'} - 1;
    }
    if (defined $genomic_align_block->{'_restricted_aln_end'}) {
	
	$align_end = $genomic_align_block->{'_restricted_aln_end'} - ($genomic_align_block->length-$align_end);
    }
    #set up bucket object for storing bucket_size number of scores 
    my $bucket_size = ($slice_length)/$display_size;
    
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
	    return $scores;
	}
    }
 
    if (!defined $window_size) {
	#set window_size to be the largest for when for loop fails
	$window_size = $window_sizes[scalar(@window_sizes)-1];
	for (my $i = 1; $i < scalar(@window_sizes); $i++) {
	    if ($bucket_size < $window_sizes[$i]) {
		$window_size = $window_sizes[$i-1];
		last;
	    }
	}
    }

    $_bucket = {diff_score => 0,
		start_pos => 0,
		end_pos => 0,
		start_seq_region_pos => 0,
		end_seq_region_pos => 0,
		called => 0,
		cnt => 0,
		size => $bucket_size,
	       current => 0};

    #Find the genomic_align_block_id. 
    #If passing in a GenomicAlignTree, find the corresponding modern genomic_align_block
    my $new_genomic_align_block;
    if (UNIVERSAL::isa($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
        $new_genomic_align_block = $genomic_align_block->get_modern_GenomicAlignBlock;
    } else {
        $new_genomic_align_block = $genomic_align_block;
    }
    #make sure reference genomic align has been set. If not set, set to be
    #first genomic_align
    my $reference_genomic_align = $new_genomic_align_block->reference_genomic_align;
    if (!$reference_genomic_align) {
	$new_genomic_align_block->reference_genomic_align($new_genomic_align_block->get_all_GenomicAligns->[0]);
    }

    #need this in case the dbID is not set ie if the $genomic_align_block has
    #been restricted
    my $gab_id;
    if (defined $new_genomic_align_block->{'dbID'}) {
        $gab_id = $new_genomic_align_block->{'dbID'};
    } else {
        $gab_id = $new_genomic_align_block->original_dbID;
    }

    my $conservation_scores = $self->_fetch_all_by_GenomicAlignBlockId_WindowSize($gab_id, $window_size, $PACKED);


    if (scalar(@$conservation_scores) == 0) {
	return $scores;
    }

    #need to reverse conservation scores if reference species is complemented
    if ($new_genomic_align_block->original_strand == 0) {
	$conservation_scores = _reverse($conservation_scores);
    }

    #reset _score_index for new conservation_scores
    $_score_index = 0;

    #print "align_start $align_start align_end $align_end start $start end $end\n";
    $scores = $self->_get_alignment_scores($conservation_scores, $align_start, 
					   $align_end, $display_type, $window_size, 
					   $new_genomic_align_block, $gab_id);

    if (scalar(@$scores) == 0) {
	return $scores;
    }

    my $all_scores;
    foreach my $this_conservation_score (@$scores) {
	$this_conservation_score->position($this_conservation_score->position + $start - 1);
	push (@$all_scores, $this_conservation_score);
    }
 
   #Find the min and max scores for y axis scaling. Save in first
    #conservation score object
    my ($min_y_axis, $max_y_axis) =  _find_min_max_score($all_scores);

    #add min and max scores to the first conservation score object
    if ((scalar @$all_scores) > 0) {
	$all_scores->[0]->y_axis_min($min_y_axis);
	$all_scores->[0]->y_axis_max($max_y_axis);
    }
   return ($all_scores);

}


=head2 store

  Arg [1]    : Bio::EnsEMBL::Compara::ConservationScore $cs
  Example    : $csa->store($cs);
  Description: Stores a conservation score object in the compara database if
               it has not been stored already.  
  Returntype : none
  Exceptions : thrown if $genomic_align_block is not a 
               Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions : thrown if the argument is not a Bio::EnsEMBL::Compara:ConservationScore
  Caller     : general
  Status     : At risk

=cut

sub store {
  my ($self,$cs) = @_;

  unless(defined $cs && ref $cs && 
	 $cs->isa('Bio::EnsEMBL::Compara::ConservationScore') ) {
      $self->throw("Must have conservation score arg [$cs]");
  }

  my $genomic_align_block = $cs->genomic_align_block;
  my $window_size = $cs->window_size;
  my $position = $cs->{position};

  #check to see if gab, window_size and position have been defined (should be unique)
  unless($genomic_align_block && $window_size && $position) {
    $self->throw("conservation score must have a genomic_align_block, window_size and position");
  }

  #check if genomic_align_block is valid
  if (!$genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
    throw("[$genomic_align_block] is not a Bio::EnsEMBL::Compara::GenomicAlignBlock");
  }
  my $genomic_align_block_id = $genomic_align_block->dbID;

  #pack the diff and expected scores if not already packed
  my $exp_packed;
  my $diff_packed;
  
  if (!$cs->packed) {
      my @exp_scores = split ' ',$cs->expected_score;
      my @diff_scores = split ' ',$cs->diff_score;

      #Check if big or little endian
      if ($is_little_endian) {
	  for (my $i = 0; $i < scalar(@exp_scores); $i++) {
	      $exp_packed .= pack($_pack_type, $exp_scores[$i]);
	      $diff_packed .= pack($_pack_type, $diff_scores[$i]);
	  }
      } else {
	  #Reverse bytes before storage on big_endian machines
	  for (my $i = 0; $i < scalar(@exp_scores); $i++) {
	      my $exp_packed_value = reverse(pack($_pack_type, $exp_scores[$i]));
	      my $diff_packed_value = reverse(pack($_pack_type, $diff_scores[$i]));
	      $exp_packed .= $exp_packed_value;
	      $diff_packed .= $diff_packed_value;
	  }
      }
  } else {
      $exp_packed = $cs->expected_score;
      $diff_packed = $cs->diff_score;
  }

  #store the conservation score
  my $sql = "INSERT into conservation_score (genomic_align_block_id,window_size,position,expected_score, diff_score) ". 
    " VALUES ('$genomic_align_block_id','$window_size', '$position', ?, ?)";
  my $sth = $self->prepare($sql);
  $sth->execute($exp_packed, $diff_packed);
  
  #update the conservation_score object so that it's adaptor is set
  $cs->adaptor($self);
}

#Internal methods

=head2 _fetch_all_by_GenomicAlignBlockId_WindowSize

  Arg  1     : integer $genomic_align_block_id 
  Arg  2     : integer $window_size
  Arg  3     : (opt) boolean $packed (default 0)
  Example    : my $conservation_scores =
                    $conservation_score_adaptor->_fetch_all_by_GenomicAlignBlockId(23134);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::ConservationScore objects. 
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::ConservationScore objects. If $packed is true, return the scores in a packed format given by $_pack_size and $_pack_type.
  Exceptions : none
  Caller     : general

=cut

sub _fetch_all_by_GenomicAlignBlockId_WindowSize {
    my ($self, $genomic_align_block_id, $window_size, $packed) = @_;
    my $conservation_scores = [];
    my $exp_scores;
    my $diff_scores;
    
    #whether to return the scores in packed or unpacked format
    #default to unpacked (space delimited string of floats)
    if (!defined $packed) {
	$packed = 0;
    }

    my $sql = qq{
  	SELECT
	    genomic_align_block_id,
	    window_size,
	    position,
	    expected_score,
	    diff_score
	FROM
	    conservation_score
	WHERE
	    genomic_align_block_id = ?
	AND
	    window_size = ?
	};

    my $sth = $self->prepare($sql);
    $sth->execute($genomic_align_block_id, $window_size);
    my $conservation_score;

    while (my @values = $sth->fetchrow_array()) {

	if (!$packed) {
	    $exp_scores = _unpack_scores($values[3]);
	    $diff_scores = _unpack_scores($values[4]);
	} else {
	    $exp_scores = $values[3];
	    $diff_scores = $values[4];
	}

	$conservation_score = Bio::EnsEMBL::Compara::ConservationScore->new_fast(
				       {'adaptor' => $self,
					'genomic_align_block_id' => $values[0],
					'window_size' => $values[1],
					'position' => ($values[2] or 1),
					'expected_score' => $exp_scores,
					'diff_score' => $diff_scores,
					'packed' => $packed});
	push(@$conservation_scores, $conservation_score);
    }
    
  #sort into numerical order based on position
  my @sorted_scores = sort {$a->{position} <=> $b->{position}} @$conservation_scores;
  return \@sorted_scores;
}


=head2 _find_min_max_score

  Arg  1     : listref of Bio::EnsEMBL::Compara::ConservationScore objects $scores
  Example    : my ($min, $max) =  _find_min_max_score($scores);
  Description: find the min and max scores used for y axis scaling
  Returntype : (float, float)
  Exceptions :
  Caller     : general
  Status     : At risk

=cut

sub _find_min_max_score {
    my ($scores) = @_;
    my $min; 
    my $max;

    foreach my $score (@$scores) {
	#find min and max of diff scores
	if (defined $score->{diff_score}) {
	    #if min hasn't been defined yet, then define min and max
	    unless (defined $min) {
		$min = $score->{diff_score};
		$max = $score->{diff_score};
	    }
	    if ($min > $score->{diff_score}) {
		$min = $score->{diff_score};
	    }
	    if ($max < $score->{diff_score}) {
		$max = $score->{diff_score};
	    }
	}
    }

    return ($min, $max);
}

=head2 _reverse

  Arg  1     : listref of Bio::EnsEMBL::Compara::ConservationScore objects $scores
  Arg  2     : int $genomic_align_block_length (number of scores)
  Example    : $conservation_scores = _reverse($conservation_scores);
  Description: reverse the conservation scores for complemented sequences
  Returntype : listref of Bio::EnsEMBL::Compara::ConservationScore objects
  Exceptions : 
  Caller     : general
  Status     : At risk

=cut

sub _reverse {
    my ($scores, $genomic_align_block_length) = @_;

    #reverse each conservation_score 
    foreach my $s (@$scores) {
	$s->reverse($genomic_align_block_length);
    }
    #reverse array so position values go from small to large
    my @rev = reverse @$scores;

    return \@rev;
}

=head2 _unpack_scores

  Arg  1     : string $scores
  Example    : $exp_scores = _unpack_scores($scores);
  Description: unpack score values retrieved from a database
  Returntype : space delimited string of floats
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _unpack_scores {
    my ($scores) = @_;
    if (!defined $scores) {
	return "";
    }
    my $num_scores = length($scores)/$_pack_size;

    my $score = "";
    if ($is_little_endian) {
	for (my $i = 0; $i < $num_scores * $_pack_size; $i+=$_pack_size) {
	    my $value = substr $scores, $i, $_pack_size;
	    $score .= unpack($_pack_type, $value) . " ";
	}
    } else {
	for (my $i = 0; $i < $num_scores * $_pack_size; $i+=$_pack_size) {
	    my $value = reverse(substr $scores, $i, $_pack_size);
	    $score .= unpack($_pack_type, $value) . " ";
	}
    }

    return $score;
}

=head2 _unpack_score

  Arg  1     : string $score
  Example    : $exp_scores = _unpack_score($score);
  Description: unpack score values retrieved from a database
  Returntype : space delimited string of floats
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _unpack_score {
    my ($pack_type, $score) = @_;

    if ($is_little_endian) {
	return unpack($pack_type, $score);
    } else {
	return unpack($pack_type, reverse($score));
    }
}


=head2 _find_score_index

  Arg  1     : listref of Bio::EnsEMBL::Compara::ConservationScore objects $scores
  Arg  2     : int $num_scores (number of scores in the array)
  Arg  3     : int $score_lengths number of scores in each row of the array
  Arg  4     : int $pos (position to find)
  Arg  5     : int $win_size (window size)
  Example    : $exp_scores = _unpack_scores($scores);
  Description: find the score index (row) that contains $pos in alignment coords  Returntype : int 
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _find_score_index {
    my ($scores, $num_scores, $score_lengths, $pos, $win_size) = @_;
    my $i;
    my $length;

    #find the score index (row) that contains $pos in alignment coords
    #use global variable $_score_index to keep track of where I am in the scores 
    #array


    #special case for first window size 
    if ($pos < $scores->[0]->{position} && $pos > ($scores->[0]->{position} - $win_size)) {
	return 0;
    }
    
    for ($i = $_score_index; $i < $num_scores; $i++) {
      my $this_position = $scores->[$i]->{position};
	$length = ($score_lengths->[$i] - 1) * $win_size;

	if ($pos >= $this_position && $pos <= $this_position + $length) {
	    $_score_index = $i;
	    return ($i);
	}

	#smaller than end so there is no score for this position
	if ($pos < ($this_position + $length)) {
	    $_score_index = $i;
	    return -1;
	}
    }
    return -1;
}


=head2 _print_scores

  Arg  1     : listref of Bio::EnsEMBL::Compara::ConservationScore objects $scores
  Arg  2     : boolean $packed (0 if not packed, 1 if packed)
  Example    : $conservation_scores = _reverse($conservation_scores);
  Description: print scores (unpack first if necessary)
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _print_scores {
    my ($scores, $packed) = @_;
    my $num_scores = scalar(@$scores);
    my $cnt;
    my ($start, $end);
    my $i;
    my @values;
    my $total_scores = 0;

    print "num scores $num_scores\n";
    for ($cnt = 0; $cnt < $num_scores; $cnt++) {
	if ($packed) {
	    $end = (length($scores->[$cnt]->expected_score) / 4);
	} else {
	    @values = split ' ', $scores->[$cnt]->diff_score;
	    $end = scalar(@values);
	}
	print "row $cnt length $end\n";
	$total_scores += $end;
	for ($i = 0; $i < $end; $i++) {
	    my $score;
	    if ($packed) {
		my $value = substr $scores->[$cnt]->expected_score, $i*$_pack_size, $_pack_size;
		$score = _unpack_score($_pack_type, $value);
	    } else {
		$score = $values[$i];
	    }
	    print "$i score $score \n";
	}
    }
    print "Total $total_scores\n";

}

=head2 _get_aligned_scores_from_cigar_line

  Arg  1     : string $cigar_line (cigar string from current alignment block)
  Arg  2     : int $start_region (start of genomic_align_block (chr coords))
  Arg  3     : int $end_region (end of genomic_align_block (chr coords))
  Arg  4     : int $start_slice (start of slice (chr coords)
  Arg  5     : int $end_slice (end of slice (chr coords))
  Arg  6     : listref of Bio::EnsEMBL::Compara::ConservationScore objects $scores
  Arg  7     : int $genomic_align_block_id (genomic align block id of current alignment block)
  Arg  8     : int $genomic_align_block_length (length of current alignment block)
  Arg  9     : string $display_type (either AVERAGE or MAX (plot average or max value))
  Arg 10     : int $win_size (window size used)
  Arg 11     : listref of Bio::EnsEMBL::Compara::ConservationScore objects $aligned_scores in slice coords

  Example    : $scores = $self->_get_aligned_scores_from_cigar_line($genomic_align->cigar_line, $genomic_align->dnafrag_start, $genomic_align->dnafrag_end, $slice->start, $slice->end, $conservation_scores, $genomic_align_block->dbID, $genomic_align_block->length, $display_type, $window_size, $scores);
  Description: Convert conservation scores from alignment coordinates into species specific chromosome (slice) coordinates for an alignment genomic_align_block
  Returntype : none, the scores are appended to $aligned_scores
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _get_aligned_scores_from_cigar_line {
    my ($self, $cigar_line, $start_region, $end_region, $start_slice, $end_slice, $scores, $genomic_align_block_id, $genomic_align_block_length, $display_type, $win_size, $aligned_scores) = @_;

    return undef if (!$cigar_line);
    
    my $num_aligned_scores = scalar(@$aligned_scores);
    my @cig = ( $cigar_line =~ /(\d*[GMDIX])/g );

    #start and end of region in alignment coords
    my $align_start = 1;
    my $align_end = $genomic_align_block_length;

    my $aligned_score;

    my $cs_index;    #conservation score row index
    my $num_scores = scalar(@$scores); #number of conservation score rows

    #position in alignment coords to the end of cigar block
    my $total_pos;  
    #position in chromosome coords to the end of cigar block
    my $total_chr_pos = $start_region; 

    my $current_pos; #current position in alignment coords
    my $chr_pos = $start_region; #current position in chromosome coords
    my $prev_position = 0; #remember previous chr position for dealing with deletions

    my $cigType; #type of cigar element
    my $cigLength; #length of cigar element

    my $i;
    my $csBlockCnt; #offset into conservation score string
    my $diff_score; #store difference score
    my @diff_scores;
    my $exp_score; #store expected score
    my @exp_scores;

    #start and end of the alignment in chromosome coords
    my $chr_start = $start_region; 
    my $chr_end = $end_region;
    
    #set start and end to be the minimum of alignment or slice
    if ($start_slice > $start_region) {
	$chr_start = $start_slice;
    }
    if ($end_slice < $end_region) {
	$chr_end = $end_slice;
    }

    #store the number of values in each row in the score array
    my $score_lengths;
    for (my $j = 0; $j < $num_scores; $j++) {
	my $length = 0;
	if (defined($scores->[$j]->{diff_score})) {
	    if ($PACKED) {
		$length = length($scores->[$j]->{diff_score})/$_pack_size;
	    } else {
		my @split_scores = split ' ', $scores->[$j]->{diff_score};
		$length = scalar(@split_scores);
	    }
	}
	push (@$score_lengths, $length);
    }

    #fill in region between previous alignment and this alignment with uncalled values

    #08.06.07 don't need to add bucket->{cnt} here
    #2015-01-19 it looks like we are calling _add_to_bucket too often. Reverting to the original values
    my $prev_chr_pos = $_bucket->{start_seq_region_pos}+$_bucket->{cnt};
    #my $prev_chr_pos = $_bucket->{start_seq_region_pos};

    #08.06.07 Fixed bug: need to add missing values only from
    #the next position to chr_start otherwise you use prev_chr_pos twice.
    #2015-01-19 it looks like we are calling _add_to_bucket too often. Reverting to the original values
    for (my $i = $prev_chr_pos; $i < $chr_start; $i+=$win_size) {
    #for (my $i = $prev_chr_pos+$win_size; $i < $chr_start; $i+=$win_size) {
	$aligned_score = _add_to_bucket($self, $display_type, $_no_score_value, $_no_score_value, $i, $start_slice, scalar(@$aligned_scores), $genomic_align_block_id, $win_size);
	if ($aligned_score) {
	    #need this to ensure that the aligned_scores array is the 
	    #correct size (passed into _add_to_bucket)
	    push(@$aligned_scores, $aligned_score);
	}
    }
    
    #convert start_region into alignment coords and initialise total_chr_pos
    while ($total_chr_pos <= $chr_start) {

	my $cigElem = $cig[$i++];

	$cigType = substr( $cigElem, -1, 1 );
	$cigLength = substr( $cigElem, 0 ,-1 );
	$cigLength = 1 unless ($cigLength =~ /^\d+$/);

	$current_pos += $cigLength;
	$total_pos += $cigLength;
	if( $cigType eq "M" || $cigType eq "I") {
	    $total_chr_pos += $cigLength;
	}
    }
    
    #find start of region in alignment coords 
    my $start_offset = $total_chr_pos - $chr_start;
    if ($cigType eq "M") {
	$align_start = (int(($total_pos - $start_offset + $win_size)/$win_size) * $win_size);
    }

    #initialise start of region in chromosome coords
    $chr_pos = $chr_start;

    #loop round in alignment coords, incrementing by win_size until either
    #reached the end of the alignment or end of the slice
    #12/03/2007 fixed bug in line below, where $chr_pos <= $chr_end. This gave
    #one too many scores when the last bucket position equaled the slice length
    #eg for slice of 1000, last bucket position = 1000, get 1001 scores but
    #slice of 2000, last bucket position 1999, get 1000 scores.
    for ($current_pos = $align_start; $current_pos <= $align_end && $chr_pos < $chr_end; $current_pos += $win_size) {

	#find conservation score row index containing current_pos. Returns -1
	#if no score found
	$cs_index = _find_score_index($scores, $num_scores, $score_lengths, $current_pos, $win_size);

	#if a score has been found, find the score in the score string and 
	#unpack it.
	unless ($cs_index == -1) {
	    $csBlockCnt = int(($current_pos - $scores->[$cs_index]->{position})/$win_size);

	    my $value;
	    if ($PACKED) {
		$value = substr $scores->[$cs_index]->expected_score, $csBlockCnt*$_pack_size, $_pack_size;
		$exp_score = _unpack_score($_pack_type, $value);
		$value = substr $scores->[$cs_index]->{diff_score}, $csBlockCnt*$_pack_size, $_pack_size;
		$diff_score = _unpack_score($_pack_type, $value);
	    } else {
		@exp_scores = split ' ', $scores->[$cs_index]->exp_score;
		$exp_score = $exp_scores[$csBlockCnt];
		@diff_scores = split ' ', $scores->[$cs_index]->diff_score;
		$diff_score = $diff_scores[$csBlockCnt];
	    } 
	}

	#find the next cigar block that is larger than current_pos
	while ($total_pos < $current_pos && $chr_pos < $chr_end) {	
	    my $cigElem = $cig[$i++];
	    
	    $cigType = substr( $cigElem, -1, 1 );
	    $cigLength = substr( $cigElem, 0 ,-1 );
	    $cigLength = 1 unless ($cigLength =~ /^\d+$/);

	    if ($cigType ne "I") {
		$total_pos += $cigLength;
	    }

	    if( $cigType eq "M"  || $cigType eq "I") {
		$total_chr_pos += $cigLength;
	    }
	}

	#total_pos is > than current_pos, so if in match, must delete this
	#excess 
	if ($cigType eq "M") {
	    $chr_pos = $total_chr_pos - ($total_pos - $current_pos + 1);
	} else {
	    $chr_pos = $total_chr_pos - 1;
	}

	#now add the scores to the bucket
	if ($cigType eq "M") {
	    if ($cs_index == -1) {
		#in cigar match but no conservation score so add _no_score_value to the bucket
		$aligned_score = _add_to_bucket($self, $display_type, $_no_score_value,$_no_score_value, $chr_pos, $start_slice, scalar(@$aligned_scores), $genomic_align_block_id, $win_size);
		if ($aligned_score) {
		    push(@$aligned_scores, $aligned_score);
		}
	    } else {
		#in cigar match and have conservation score

		$aligned_score = _add_to_bucket($self, $display_type, $exp_score, $diff_score, $chr_pos, $start_slice, scalar(@$aligned_scores), $genomic_align_block_id, $win_size);
		if ($aligned_score) {
		    push(@$aligned_scores, $aligned_score);
		}
	    }
	} else {
	    #not in cigar match so only add the next conservation score or
	    #_no_score_value if this isn't a score
	    if ($prev_position != $chr_pos) {
		if ($cs_index == -1) {
		    $aligned_score = _add_to_bucket($self, $display_type, $_no_score_value, $_no_score_value, $chr_pos, $start_slice, scalar(@$aligned_scores), $genomic_align_block_id, $win_size);
		    if ($aligned_score) {
			push(@$aligned_scores, $aligned_score);
		    }
		} else {
		    $aligned_score = _add_to_bucket($self, $display_type, $exp_score, $diff_score, $chr_pos, $start_slice, scalar(@$aligned_scores), $genomic_align_block_id, $win_size);
		    if ($aligned_score) {
			push(@$aligned_scores, $aligned_score);
		    }
		}
	    }
	}
	$prev_position = $chr_pos;
    }
}

=head2 _get_aligned_scores_from_cigar_line_fast

  Arg  1     : string $cigar_line (cigar string from current alignment block)
  Arg  2     : int $start_region (start of genomic_align_block (chr coords))
  Arg  3     : int $end_region (end of genomic_align_block (chr coords))
  Arg  4     : int $start_slice (start of slice (chr coords)
  Arg  5     : int $end_slice (end of slice (chr coords))
  Arg  6     : listref of Bio::EnsEMBL::Compara::ConservationScore objects $scores
  Arg  7     : int $genomic_align_block_id (genomic align block id of current alignment block)
  Arg  8     : int $genomic_align_block_length (length of current alignment block)
  Arg  9     : string $display_type (either AVERAGE or MAX (plot average or max value))
  Arg 10     : listref of Bio::EnsEMBL::Compara::ConservationScore objects $aligned_scores in slice coords

  Example    : $scores = $self->_get_aligned_scores_from_cigar_line_fast($genomic_align->cigar_line, $genomic_align->dnafrag_start, $genomic_align->dnafrag_end, $slice->start, $slice->end, $conservation_scores, $genomic_align_block->dbID, $genomic_align_block->length, $display_type, $scores);
  Description: Faster method to than _get_aligned_scores_from_cigar_line. This
               method does not bin the scores and can be used if only require
               one score per base in the alignment
  Returntype : none, the scores are appended to $aligned_scores
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _get_aligned_scores_from_cigar_line_fast {
    my ($self, $cigar_line, $start_region, $end_region, $start_slice, $end_slice, $scores, $genomic_align_block_id, $genomic_align_block_length, $display_type, $aligned_scores) = @_;

    return undef if (!$cigar_line);
    
    my $num_aligned_scores = scalar(@$aligned_scores);
    my @cig = ( $cigar_line =~ /(\d*[GMDIX])/g );

    #start and end of region in alignment coords
    my $align_start = 1;
    my $align_end = $genomic_align_block_length;

    my $aligned_score;

    my $cs_index;    #conservation score row index
    my $num_scores = scalar(@$scores); #number of conservation score rows

    #position in alignment coords to the end of cigar block
    my $total_pos;  
    #position in chromosome coords to the end of cigar block
    my $total_chr_pos = $start_region; 

    my $current_pos; #current position in alignment coords
    my $chr_pos = $start_region; #current position in chromosome coords
    my $prev_position = 0; #remember previous chr position for dealing with deletions

    my $cigType; #type of cigar element
    my $cigLength; #length of cigar element

    my $i;
    my $csBlockCnt; #offset into conservation score string
    my $diff_score; #store difference score
    my @diff_scores;
    my $exp_score; #store expected score
    my @exp_scores;

    #start and end of the alignment in chromosome coords
    my $chr_start = $start_region; 
    my $chr_end = $end_region;
    
    #set start and end to be the minimum of alignment or slice
    if ($start_slice > $start_region) {
	$chr_start = $start_slice;
    }
    if ($end_slice < $end_region) {
	$chr_end = $end_slice;
    }

    #store the number of values in each row in the score array
    my $score_lengths;
    for (my $j = 0; $j < $num_scores; $j++) {
	my $length = 0;
	if (defined($scores->[$j]->diff_score)) {
	    if ($PACKED) {
		$length = length($scores->[$j]->diff_score)/$_pack_size;
	    } else {
		my @split_scores = split ' ', $scores->[$j]->diff_score;
		$length = scalar(@split_scores);
	    }
	}
	push (@$score_lengths, $length);
    }
    #convert start_region into alignment coords and initialise total_chr_pos
    while ($total_chr_pos <= $chr_start) {

	my $cigElem = $cig[$i++];

	$cigType = substr( $cigElem, -1, 1 );
	$cigLength = substr( $cigElem, 0 ,-1 );
	$cigLength = 1 unless ($cigLength =~ /^\d+$/);

	$current_pos += $cigLength;

	if ($cigType ne "I") {
	    $total_pos += $cigLength;
	}

	if( $cigType eq "M" || $cigType eq "I") {
	    $total_chr_pos += $cigLength;
	}
    }

    #find start of region in alignment coords 
    my $start_offset = $total_chr_pos - $chr_start;
    if ($cigType eq "M") {
#	$align_start = (int(($total_pos - $start_offset + $win_size)/$win_size) * $win_size);
	$align_start = $total_pos - $start_offset + 1;
    }

    #initialise start of region in chromosome coords
    $chr_pos = $chr_start - 1; #Need subtract 1 to allow for a single base ie chr_start=chr_end.

    #Initialise array of index of positions to index in the scores array

    my @hash_positions = ((-1) x (($align_end-$align_start+1)));

    for (my $i = 0; $i < @$scores; $i++) {
	my $score = $scores->[$i];
	my $length = $score_lengths->[$i] - 1;
	my $start = $score->{position};
	my $end = $score->{position} + $length;

	for (my $j = $start; $j <= $end; $j++) {
	    $hash_positions[$j] = $i;
	}
    }

    #loop round in alignment coords, incrementing by win_size until either
    #reached the end of the alignment or end of the slice
    #12/03/2007 fixed bug in line below, where $chr_pos <= $chr_end. This gave
    #one too many scores when the last bucket position equaled the slice length
    #eg for slice of 1000, last bucket position = 1000, get 1001 scores but
    #slice of 2000, last bucket position 1999, get 1000 scores.
    for ($current_pos = $align_start; $current_pos <= $align_end && $chr_pos < $chr_end; $current_pos += 1) {

	#find conservation score row index containing current_pos. Returns -1
	#if no score found
	#$cs_index = _find_score_index($scores, $num_scores, $score_lengths, $current_pos, $win_size);
	$cs_index = $hash_positions[$current_pos];
	if (!defined $cs_index) {
	    $cs_index = -1;
	}

	#if a score has been found, find the score in the score string and 
	#unpack it.
	unless ($cs_index == -1) {
	    $csBlockCnt = $current_pos - $scores->[$cs_index]->{position};

	    my $value;
	    if ($PACKED) {
		$value = substr $scores->[$cs_index]->{expected_score}, $csBlockCnt*$_pack_size, $_pack_size;
		$exp_score = _unpack_score($_pack_type, $value);
		$value = substr $scores->[$cs_index]->{diff_score}, $csBlockCnt*$_pack_size, $_pack_size;
		$diff_score = _unpack_score($_pack_type, $value);
	    } else {
		@exp_scores = split ' ', $scores->[$cs_index]->exp_score;
		$exp_score = $exp_scores[$csBlockCnt];
		@diff_scores = split ' ', $scores->[$cs_index]->diff_score;
		$diff_score = $diff_scores[$csBlockCnt];
	    } 
	}

	#find the next cigar block that is larger than current_pos
	while ($total_pos < $current_pos && $chr_pos < $chr_end) {	
	    my $cigElem = $cig[$i++];
	    
	    $cigType = substr( $cigElem, -1, 1 );
	    $cigLength = substr( $cigElem, 0 ,-1 );
	    $cigLength = 1 unless ($cigLength =~ /^\d+$/);
	    
	    if ($cigType ne "I") {
		$total_pos += $cigLength;
	    }
	    #if( $cigType eq "M" ) {
	    if( $cigType eq "M" || $cigType eq "I") {
		$total_chr_pos += $cigLength;
	    }
	}

	#now add the scores to the bucket
	if ($cigType eq "M") {
	    $chr_pos = $total_chr_pos - ($total_pos - $current_pos + 1);
	    #print "chr_pos=$chr_pos total_chr_pos=$total_chr_pos total_pos=$total_pos current_pos=$current_pos diff_score=$diff_score\n";

	    if ($cs_index != -1) {
		#in cigar match and have conservation score

		#bit of a hack to turn 0's stored in the database to undefs
		if (defined($diff_score) && $diff_score == 0) {
		    $diff_score = $_no_score_value;
		    $exp_score = $_no_score_value;
		}
		#print "final pos " . ($chr_pos - $start_slice + 1) .  " $diff_score\n";
		$aligned_score = Bio::EnsEMBL::Compara::ConservationScore->new_fast(
		      {'adaptor' => $self,
		      'genomic_align_block_id' => $genomic_align_block_id,
		      'window_size' => 1,
		      'position' => $chr_pos - $start_slice + 1,
		      'seq_region_pos' => $chr_pos,
		      'diff_score' => $diff_score,
		      'expected_score' => $exp_score}
		      );
		 push(@$aligned_scores, $aligned_score);
	    }
	} else {
	    $chr_pos = $total_chr_pos - 1;
	    #not in cigar match so only add the next conservation score or
	    #_no_score_value if this isn't a score
	    if ($prev_position != $chr_pos) {
		if ($cs_index != -1) {
		    $aligned_score = Bio::EnsEMBL::Compara::ConservationScore->new_fast(
		      {'adaptor' => $self,
		      'genomic_align_block_id' => $genomic_align_block_id,
		      'window_size' => 1,
		      'position' => $chr_pos - $start_slice + 1,
		      'seq_region_pos' => $chr_pos,
		      'diff_score' => $diff_score,
		      'expected_score' => $exp_score}
		      );
		    push(@$aligned_scores, $aligned_score);
		}
	    }
	}
	$prev_position = $chr_pos;
    }
}

=head2 _get_alignment_scores

  Arg  1     : listref of Bio::EnsEMBL::Compara::ConservationScore objects $scores
  Arg  2     : int $align_start (start position in alignment coords)
  Arg  3     : int $align_end (end position in alignment coords)
  Arg  4     : string $display_type (either AVERAGE or MAX (plot average or max value))
  Arg  5     : int $win_size (window size used)
  Arg  6     : ref to Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Example    : $scores = $self->_get_alignment_scores($conservation_scores, 
               1, 100000, "AVERAGE", 10, $genomic_align_block);
  Description: get scores for an alignment in alignment coordinates
  Returntype : listref of Bio::EnsEMBL::Compara::ConservationScore objects $scores in alignment coordinates
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _get_alignment_scores {
    my ($self, $conservation_scores, $align_start, $align_end, $display_type, $window_size, $genomic_align_block, $genomic_align_block_id) = @_;

    my $num_rows = scalar(@$conservation_scores);
    my @exp_scores;
    my $exp_score;
    my @diff_scores;
    my $diff_score;
    my $aligned_scores = [];
    my $pos;

    my $genomic_align = $genomic_align_block->reference_genomic_align;
    my $i = 0;
    my $total_chr_pos = $genomic_align->dnafrag_start;
    my $total_pos;
    my $start_uncalled_region = 0;
    my $end_uncalled_region = 0;

    my $score_lengths;
    my $start_offset = 0;
    my $end_offset = 0;
    my $start = -1; 
    my $end = -1;

    #need to find the start_offset for align_start and end_offset for align_end
    #in the conservation score row
    for (my $j = 0; $j < $num_rows; $j++) {

	my $length = 0;
	if (defined($conservation_scores->[$j]->diff_score)) {
	    if ($PACKED) {
		$length = length($conservation_scores->[$j]->diff_score)/$_pack_size;
	    } else {
		my @split_scores = split ' ', $conservation_scores->[$j]->diff_score;
		$length = scalar(@split_scores);
	    }
	}
	$length = ($length-1) * $window_size;
	
	#special case for align_start before the first score position eg when
	#have window sizes > 1
	if ($start == -1 && $align_start < $conservation_scores->[0]->{position}) {
	    $start = 0;
	    $start_offset = 0;
	}

	#align_start within a called region
	if ($start == -1 && $align_start >= $conservation_scores->[$j]->{position} && $align_start <= $conservation_scores->[$j]->{position} + $length) {
	    $start= $j;
	    $start_offset= ($align_start - $conservation_scores->[$j]->{position})/$window_size;
	}


	#align_start in an uncalled region
	if ($start == -1 && $align_start < ($conservation_scores->[$j]->{position})) {
	    $start= $j;
	    $start_offset = 0;
	    $start_uncalled_region = 1;
 	}

         #align_end within a called region. And can stop
	if ($align_end >= $conservation_scores->[$j]->{position} && $align_end <= $conservation_scores->[$j]->{position} + $length) {
	    $end= $j;
	    $end_offset= int(($align_end - $conservation_scores->[$j]->{position})/$window_size);
	    last;
	}

         #align_end within an uncalled region. And can stop
	if ($align_end < ($conservation_scores->[$j]->{position})) {
	    $end= $j-1;
	    $end_offset = 0;
	    $end_uncalled_region = 1;
	    last;
 	}	
    }
    
    #haven't found end because it is beyond the last position in 
    #conservation_scores which can happen for window_sizes > 1
    if ($end == -1) {
	$end = $num_rows-1;
	$end_offset = int(($align_end - $conservation_scores->[$end]->{position})/$window_size);
    }

    #go through rows $start to $end
    for (my $i = $start; $i <= $end; $i++) {
	my $num_scores = 0;
	if (defined($conservation_scores->[$i]->diff_score)) {
            if ($PACKED) {
                $num_scores = length($conservation_scores->[$i]->diff_score)/$_pack_size;
            } else {
                @exp_scores = split ' ', $conservation_scores->[$i]->exp_score;
                @diff_scores = split ' ', $conservation_scores->[$i]->diff_score;
                $num_scores = scalar(@diff_scores);
            }
	}

	#last row. If align_end is within a called region, need to recalculate
        #num_scores
	if ($i == $end && !$end_uncalled_region) {
	    #num_scores can never be greater than scalar(@diff_scores)
	    if ($end_offset+1 < $num_scores) {
		$num_scores = $end_offset+1;
	    }
	}
	
	$pos = $conservation_scores->[$i]->{position};

	#first time round start at offset if align_start is within a called 
	#region
	for (my $j = int($start_offset); $j < $num_scores; $j++) {

	    #increment pos by start_offset
	    $pos += ($start_offset*$window_size);

	    #set offset to 0 for all other rows
	    $start_offset = 0;

	    if ($PACKED) {
		my $value;
		$value = substr $conservation_scores->[$i]->expected_score, $j*$_pack_size, $_pack_size;
		$exp_score = _unpack_score($_pack_type, $value);

		$value = substr $conservation_scores->[$i]->diff_score, $j*$_pack_size, $_pack_size;
		$diff_score = _unpack_score($_pack_type, $value);
	    } else {
		$exp_score = $exp_scores[$j];
		$diff_score = $diff_scores[$j];
	    } 

	    my $aligned_score = 0;
	    $aligned_score = _add_to_bucket($self, $display_type, $exp_score, $diff_score, $pos - $align_start + 1, 1, scalar(@$aligned_scores), $genomic_align_block_id, $window_size);  

	    if ($aligned_score) {
		push(@$aligned_scores, $aligned_score);
	    }
	    $pos+=$window_size;
	}
	#add uncalled scores for regions between called blocks
	my $next_pos;
	if ($i < $end) {
	    $next_pos = $conservation_scores->[$i+1]->{position};
	} else {
	    $next_pos = $align_end+1;
	}
	  
   	for (my $j = $pos; $j < $next_pos; $j+=$window_size) {
	    my $aligned_score = _add_to_bucket($self, $display_type, $_no_score_value, $_no_score_value, ($j - $align_start + 1), 1, scalar(@$aligned_scores), $genomic_align_block_id, $window_size);  
   	    if ($aligned_score) {
		push(@$aligned_scores, $aligned_score);
		last;
	    }
   	}
    }
    #foreach my $s (@$aligned_scores) {
	#print STDERR "score " . $s->position . " " . $s->diff_score . "\n";
    #}

    
    #hack to remove zeros after they've been added. Better to not add them
    #in the first place (but haven't got the code working yet)
    #remove _no_score_values from aligned_scores array
    $i = 0;
    while ($i < scalar(@$aligned_scores)) {
    	if (!defined($_no_score_value) && 
    	    !defined($aligned_scores->[$i]->diff_score)) {
	    splice @$aligned_scores, $i, 1;
    	} elsif (defined($_no_score_value) && 
    		 $aligned_scores->[$i]->diff_score == $_no_score_value) {
    	    splice @$aligned_scores, $i, 1;
	} else {
    	    $i++;
	}
     }

    #need to shift positions if align_start is in an uncalled region because
    #need to add the uncalled positions up to the start of the next called 
    #block
   # for (my $i = 0; $i < scalar(@$aligned_scores); $i++) {
#	$aligned_scores->[$i]->{position} = $aligned_scores->[$i]->{position}-$align_start+1;  
 #     }

    return $aligned_scores;
}

=head2 _add_to_bucket

  Arg  1     : string $display_type (either AVERAGE or MAX (plot average or max value))
  Arg  2     : float $exp_score (expected score to be added to bucket)
  Arg  3     : float $diff_score (difference score to be added to bucket)
  Arg  4     : int $chr_pos (position in slice of reference species)
  Arg  5     : int $start_slice (start position of slice)
  Arg  6     : int $num_buckets (number of buckets used so far)
  Arg  7     : int $genomic_align_block_id (genomic_align_block_id of 
               alignment block)
  Arg  8     : int $win_size window size used
  Example    : $aligned_score = _add_to_bucket($self, "AVERAGE", $exp_score, $diff_score, $chr_pos, $start_slice, scalar(@$aligned_scores), $genomic_align_block_id, $win_size);
  Description: Add scores to bucket until it is full (given by size) and then 
               average the called scores or take the maximum (given by 
               display_type). Once the bucket is full, create a new 
               conservation score object
  Returntype : ref to Bio::EnsEMBL::Compara::ConservationScore object if the
               bucket if full or 0 if it isn't full yet
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _add_to_bucket {
    #bucket structure:
    #cnt: keep track of number of scores been added
    #start_pos: position of first score in slice coords
    #start_seq_region_pos: position of first score in chr coords
    #exp_score: sum or max of expected scores
    #diff_score: sum or max of difference scores
    #called: number of called scores (used to average)
    #size: number of bases/bucket

    my ($self, $display_type, $exp_score, $diff_score, $chr_pos, $start_slice, $num_buckets, $genomic_align_block_id, $win_size) = @_;
    my $p = 0;
    my $s;
    my $final_exp_score;
    my $final_diff_score;
    my $filled_bucket = 0;

    #bit of a hack to turn 0's stored in the database to undefs
    if (defined($diff_score) && $diff_score == 0) {
	$diff_score = $_no_score_value;
    }

    #store start of bucket position
    if ($_bucket->{cnt} == 0) {

	$_bucket->{start_pos} = $chr_pos - $start_slice + 1;
	$_bucket->{start_seq_region_pos} = $chr_pos;

	#initialise diff_score for new bucket
	if ($display_type eq "AVERAGE") {
	    $_bucket->{exp_score} = 0;
	    $_bucket->{diff_score} = 0;
	} else {
	    $_bucket->{exp_score} = $exp_score;
	    $_bucket->{diff_score} = $diff_score;
	}
    }

    #convert chr_pos into slice coords
    my $end_pos = $chr_pos - $start_slice + 1;

    my $end_seq_region_pos = $chr_pos;

    if ($display_type eq "AVERAGE") {

	#store the scores
	if (defined $_no_score_value) {
	    if ($diff_score != $_no_score_value) {
		$_bucket->{exp_score} += $exp_score;
		$_bucket->{diff_score} += $diff_score;
		$_bucket->{called}++;
	    }
	} else {
	    if (defined $diff_score) {
		$_bucket->{exp_score} += $exp_score;
		$_bucket->{diff_score} += $diff_score;
		$_bucket->{called}++;
	    }
	}

	$_bucket->{cnt}++;

	#check to see if filled bucket NB end_pos is in slice coords
	#so multiply size (number of bases/bucket) by number of buckets used so
	#far (plus 1 because it starts at 0)

	my $num_align_scores = floor($end_pos/ $_bucket->{size});

	if ($num_align_scores > $_bucket->{current}) {
	  $_bucket->{current} = $num_align_scores;

	    #take average position 
	    $p = int(($end_pos + $_bucket->{start_pos})/2);
	    $s = int(($end_seq_region_pos + $_bucket->{start_seq_region_pos})/2);
	    #take average score
	    if ($_bucket->{called} == 0) {
		$final_exp_score  = $_no_score_value;
		$final_diff_score  = $_no_score_value;
	    } else {
		#should average over complete bucket even if not all values are
		#called
		#$final_score = $_bucket->{diff_score}/$_bucket->{called};
		$final_exp_score = $_bucket->{exp_score}/$_bucket->{cnt};
		$final_diff_score = $_bucket->{diff_score}/$_bucket->{cnt};
	    } 
	    $filled_bucket = 1;
	}
    } else {
	#find the max score of the difference, and store the exp scores
	#for this too.

	#bucket->{diff_score} will be undefined if the first score in the
	#bucket is undefined.
	if (!defined $_bucket->{diff_score} && defined($diff_score)) {
	    $_bucket->{diff_score} = $diff_score;
	    $_bucket->{exp_score} = $exp_score;
	}
	if (defined($diff_score) && $_bucket->{diff_score} < $diff_score) {
	    $_bucket->{diff_score} = $diff_score;
	    $_bucket->{exp_score} = $exp_score;
	}
	$_bucket->{cnt}++;

	#check to see if filled bucket NB end_pos is in slice coords
	#so multiply size (number of bases/bucket) by number of buckets used so
	#far (plus 1 because it starts at 0)
	if ($end_pos >= ($_bucket->{size} * ($num_buckets+1))) {
	    $p = int(($end_pos + $_bucket->{start_pos})/2);
	    $s = int(($end_seq_region_pos + $_bucket->{start_seq_region_pos})/2);

	    $final_exp_score = $_bucket->{exp_score};
	    $final_diff_score = $_bucket->{diff_score};
	    $filled_bucket = 1;
	}
    }
    #if bucket is full, create a new conservation score
    #if (defined $final_diff_score) {
    if ($filled_bucket) {
	my $aligned_score = Bio::EnsEMBL::Compara::ConservationScore->new_fast(
		      {'adaptor' => $self,
		      'genomic_align_block_id' => $genomic_align_block_id,
		      'window_size' => $win_size,
		      'position' => ($p or 1),
		      'seq_region_pos' => $s,
		      'diff_score' => $final_diff_score,
		      'expected_score' => $final_exp_score}
		      );
	
	$_bucket->{exp_score} = 0;
	$_bucket->{diff_score} = 0;
	$_bucket->{cnt} = 0;
	$_bucket->{called} = 0;
	$filled_bucket = 0;

	return $aligned_score;
    }
    #return 0 if not filled bucket
    return 0;
}

=head2 _get_all_ref_genomic_aligns

  Arg  1     : ref to Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Arg  2     : ref to Bio::EnsEMBL::Slice object
  Example    :  my $light_genomic_aligns = $self->_get_all_ref_genomic_aligns($ma_mlss, $slice);
  Description: Retrieve from the database some genomic_align information 
               relating to only the slice species. 
  Returntype : listref of hash containing a subset of genomic_align fields
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _get_all_ref_genomic_aligns {
    my ($self, $mlss, $slice) = @_;

    my $light_genomic_aligns = []; # Returned value

    my $slice_adaptor = $slice->adaptor();
    if(!$slice_adaptor) {
	warning("Slice has no attached adaptor. Cannot get Compara alignments.");
	return $light_genomic_aligns;
    }

    my $dnafrag_adaptor = $self->db->get_DnaFragAdaptor;
    my $dnafrag = $dnafrag_adaptor->fetch_by_Slice($slice);
    next if (!$dnafrag);

    my $max_alignment_length = $mlss->max_alignment_length;
    my $lower_bound = $slice->start - $max_alignment_length;
    
    my $sql = qq{
          SELECT 
             genomic_align_block_id,
             dnafrag_start,
             dnafrag_end,
             dnafrag_strand,
             cigar_line,
             length
          FROM 
             genomic_align 
          LEFT JOIN
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

    $sth->execute($mlss->dbID,  $dnafrag->dbID, $slice->end, $slice->start, $lower_bound);

    my ($genomic_align_block_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line, $length);
    $sth->bind_columns(\$genomic_align_block_id, \$dnafrag_start, \$dnafrag_end, \$dnafrag_strand, \$cigar_line, \$length);

    while ($sth->fetch) {
	my $light_genomic_align = {
	    genomic_align_block_id => $genomic_align_block_id,
            dnafrag_start => $dnafrag_start,
            dnafrag_end => $dnafrag_end,
	    dnafrag_strand => $dnafrag_strand,
            cigar_line => $cigar_line,
            length => $length};

	push @$light_genomic_aligns, $light_genomic_align;
    }  
    return $light_genomic_aligns;
}

sub count_by_mlss_id {
    my ($self, $mlss_id) = @_;

    my $sql = "SELECT count(*) FROM conservation_score cs JOIN genomic_align_block gab USING(genomic_align_block_id) JOIN method_link_species_set_tag mlss_tag ON(gab.method_link_species_set_id=mlss_tag.value) WHERE mlss_tag.tag = 'msa_mlss_id' AND mlss_tag.method_link_species_set_id = ?";

    my $sth = $self->prepare($sql);
    $sth->execute($mlss_id);
    my ($count) = $sth->fetchrow_array();
    $sth->finish();

    return $count;
}


1;

