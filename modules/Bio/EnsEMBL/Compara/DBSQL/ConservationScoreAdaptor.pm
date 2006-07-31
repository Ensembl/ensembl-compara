#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor
#
# Cared for by Kathryn Beal <kbeal@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

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

  Retrieve difference score data from the database
     $conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice);
     $conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice, 800, "AVERAGE", 10);

=head1 DESCRIPTION

This module is used to access data in the conservation_score table

Not all bases in an alignment have a conservation score (for example,
if there is insufficient coverage), termed here as 'uncalled'. To keep storage
space in the database to a minimum, only 'called' values are stored. Where 
there is a region of 'uncalled' bases, a new row is started and the position of
the first 'called' score is set in the conservation_score position field. 
Small regions of uncalled scores (upto 10 scores) are allowed to prevent large 
numbers of small conservation_score objects being created.
For example, for an alignment which has 96 called bases, followed by 20 
uncalled bases followed by 13 called bases would have a conservation_score
table looking like:
genomic_align_block_id   position   window_size  observed_score .....
    32533                   1          1         "string of 96 scores"
    32533                   117        1         "string of 13 scores"


=head1 AUTHOR - Kathryn Beal

This modules is part of the Ensembl project http://www.ensembl.org

Email kbeal@ebi.ac.uk

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::ConservationScore;
use Bio::EnsEMBL::Utils::Exception qw(throw info deprecate);

#global variables

#store as 4 byte float. If change here, must also change in 
#ConservationScore.pm
my $_pack_size = 4;
my $_pack_type = "f";

my $_bucket; 
my $_score_index = 0;
my $_no_score_value = 0.0; #value if no score

my $PACKED = 1;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 fetch_all_by_MethodLinkSpeciesSet_Slice

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set 
  Arg  2     : Bio::EnsEMBL::Slice $slice
  Arg  3     : (opt) integer $display_size (default 1000)
  Arg  4     : (opt) string $display_type (one of "AVERAGE" or "MAX") (default "MAX")
  Arg  5     : (opt) integer $window_size
  Example    : my $conservation_scores =
                    $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice, 1000, "MAX", 10);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::ConservationScore objects. 
               Each conservation score object contains a single score in slice 
               coordinates ie the position field contains the slice coordinate
               and the diff score field contains a single float. 
               The min and max y axis values for the array of 
               conservation score objects are set in the first conservation 
               score object (index 0). Display_size is the number of scores
               that will be returned. If the slice length is larger than the
               display_size, the scores will either be averaged if the 
               display_type is "AVERAGE" or the maximum taken if display_type
               is "MAXIMUM". If the window_size is not specified, the
               window_size is determined as the largest window_size 
               which gives at least display_size number of scores. 
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::ConservationScore objects. 
  Caller     : object::methodname

=cut

sub fetch_all_by_MethodLinkSpeciesSet_Slice {
    my ($self, $method_link_species_set, $slice, $display_size, $display_type, $window_size) = @_;

    #get genomic align blocks in the slice
    my $genomic_align_block_adaptor = $self->db->get_GenomicAlignBlockAdaptor;
    my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice);

    my $scores = [];
    if (scalar(@$genomic_align_blocks == 0)) {
	return $scores;
    }

    #default display_size is 1000
    if (!defined $display_size) {
	$display_size = 1000;
    }

    #default display_mode is MAX
    if (!defined $display_type) {
	$display_type = "MAX";
    }

    #set up bucket object for storing bucket_size number of scores 
    my $bucket_size = ($slice->end-$slice->start+1)/$display_size;
    
    #default window size is the largest bucket that gives at least 
    #display_size values ie get speed but reasonable resolution
    my @window_sizes = (1, 10, 100, 500);
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
		size => $bucket_size};

    foreach my $genomic_align_block (@$genomic_align_blocks) { 
	#get genomic_align for this slice
	my $genomic_align = $genomic_align_block->reference_genomic_align;
	
	my $conservation_scores = $self->_fetch_all_by_GenomicAlignBlockId_WindowSize($genomic_align_block->dbID, $window_size, $PACKED);
	
	if (scalar(@$conservation_scores) == 0) {
	    next;
	}

	if ($genomic_align_block->get_original_strand == 0) {
	    $conservation_scores = _reverse($conservation_scores);
	}
 
	#reset _score_index for new conservation_scores
	$_score_index = 0;

	$scores = _get_aligned_scores_from_cigar_line($self, $genomic_align->cigar_line, $genomic_align->dnafrag_start, $genomic_align->dnafrag_end, $slice->start, $slice->end, $conservation_scores, $genomic_align_block->dbID, $genomic_align_block->length, $display_type, $window_size, $scores);
    }

    if (scalar(@$scores) == 0) {
	return $scores;
    }

    #add last no_score_values if haven't got to end of slice
    if (scalar(@$genomic_align_blocks > 0)) {
	my $genomic_align_block = $genomic_align_blocks->[@$genomic_align_blocks - 1];
	my $genomic_align = $genomic_align_block->reference_genomic_align;
	my $num_scores = scalar(@$scores);
	for (my $i = $genomic_align->dnafrag_end; $i < $slice->end; $i+=$window_size) {
	    my $aligned_score = _add_to_bucket($self, $display_type, $_no_score_value, $i, $slice->start, scalar(@$scores), $genomic_align_block->dbID, $window_size);
	    
	    if ($aligned_score) {
		push(@$scores, $aligned_score);
	    }
	}
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
  Arg  2     : (opt) integer $display_size (default 1000)
  Arg  3     : (opt) string $display_type (one of "AVERAGE" or "MAX") (default "MAX")
  Arg  4     : (opt) integer $window_size
  Example    : my $conservation_scores =
                    $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock($genomic_align_block, 1000, "MAX", 10);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::ConservationScore objects. 
               Each conservation score object contains a single score in 
               alignment coordinates ie the position field contains the
               alignment coordinate and the diff score field contains a 
               single float. The min and max y axis values for
               the array of conservation score objects are set in the first 
               conservation score object (index 0). Display_size is the number 
               of scores that will be returned. If the slice length is larger 
               than the display_size, the scores will either be averaged if the
               display_type is "AVERAGE" or the maximum taken if display_type
               is "MAXIMUM". If the window_size is not specified, the
               window_size is determined as the largest window_size 
               which gives at least display_size number of scores. 
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::ConservationScore objects. 
  Caller     : object::methodname

=cut
sub fetch_all_by_GenomicAlignBlock {
    my ($self, $genomic_align_block, $display_size, $display_type, $window_size) = @_;

    my $scores = [];

    #default display_size is 1000
    if (!defined $display_size) {
	$display_size = 1000;
    }

    #default display_mode is MAX
    if (!defined $display_type) {
	$display_type = "MAX";
    }

    #set up bucket object for storing bucket_size number of scores 
    #my $bucket_size = int(($genomic_align_block->length)/$display_size + 0.5);
    my $bucket_size = ($genomic_align_block->length)/$display_size;
    
    #default window size is the largest bucket that gives at least 
    #display_size values ie get speed but reasonable resolution
    my @window_sizes = (1, 10, 100, 500);
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
		size => $bucket_size};
    
    my $conservation_scores = $self->_fetch_all_by_GenomicAlignBlockId_WindowSize($genomic_align_block->dbID, $window_size, $PACKED);

    if (scalar(@$conservation_scores) == 0) {
	return $scores;
    }

    #need to reverse conservation scores if reference species is complemented
    if ($genomic_align_block->get_original_strand == 0) {
	$conservation_scores = _reverse($conservation_scores);
    }
    
    #reset _score_index for new conservation_scores
    $_score_index = 0;

    $scores = $self->_get_alignment_scores($conservation_scores, $display_type, $window_size, $genomic_align_block);


    if (scalar(@$scores) == 0) {
	return $scores;
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

=cut

sub store {
  my ($self,$cs) = @_;

  unless(defined $cs && ref $cs && 
	 $cs->isa('Bio::EnsEMBL::Compara::ConservationScore') ) {
      $self->throw("Must have conservation score arg [$cs]");
  }

  my $genomic_align_block = $cs->genomic_align_block;
  my $window_size = $cs->window_size;
  my $position = $cs->position;

  #check to see if gab, window_size and position have been defined (should be unique)
  unless($genomic_align_block && $window_size && $position) {
    $self->throw("conservation score must have a genomic_align_block, window_size and position");
  }

  #check if genomic_align_block is valid
  if (!$genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
    throw("[$genomic_align_block] is not a Bio::EnsEMBL::Compara::GenomicAlignBlock");
  }
  my $genomic_align_block_id = $genomic_align_block->dbID;

  #pack the observed and expected scores if not already packed
  my $obs_packed;
  my $exp_packed;
  my $diff_packed;
  
  if (!$cs->packed) {
      my @obs_scores = split ' ',$cs->observed_score;
      my @exp_scores = split ' ',$cs->expected_score;
      my @diff_scores = split ' ',$cs->diff_score;

      for (my $i = 0; $i < scalar(@obs_scores); $i++) {
	  $obs_packed .= pack($_pack_type, $obs_scores[$i]);
	  $exp_packed .= pack($_pack_type, $exp_scores[$i]);
	  $diff_packed .= pack($_pack_type, $diff_scores[$i]);
      }
  } else {
      $obs_packed = $cs->observed_score;
      $exp_packed = $cs->expected_score;
      $diff_packed = $cs->diff_score;
  }

  #check if already exists
  my $sth = $self->prepare("
      SELECT genomic_align_block_id 
      FROM conservation_score
      WHERE genomic_align_block_id='$genomic_align_block_id' AND window_size='$window_size' AND position = '$position'
   ");

  $sth->execute;

  my $gab_id = $sth->fetchrow_array();

  #only add conservation_score if one doesn't already exist
  if (!$gab_id) {

      #if the conservation score has not been stored before, store it now
      my $sql = "INSERT into conservation_score (genomic_align_block_id,window_size,position,observed_score,expected_score, diff_score) ". 
	  " VALUES ('$genomic_align_block_id','$window_size', '$position', ?, ?, ?)";
      my $sth = $self->prepare($sql);
      $sth->execute($obs_packed, $exp_packed, $diff_packed);
  }
  
  #update the conservation_score object so that it's adaptor is set
  $cs->adaptor($self);
}

#Internal methods

#  Arg  1     : integer $genomic_align_block_id 
#  Arg  2     : integer $window_size
#  Arg  3     : (opt) boolean $packed (default 0)
#  Example    : my $conservation_scores =
#                    $conservation_score_adaptor->fetch_all_by_GenomicAlignBlockId(23134);
#  Description: Retrieve the corresponding
#               Bio::EnsEMBL::Compara::ConservationScore objects. 
#  Returntype : ref. to an array of Bio::EnsEMBL::Compara::ConservationScore objects. If $packed is true, return the scores in a packed format given by $_pack_size and $_pack_type.

#  Caller     : object::methodname

sub _fetch_all_by_GenomicAlignBlockId_WindowSize {
    my ($self, $genomic_align_block_id, $window_size, $packed) = @_;
    my $conservation_scores = [];
    my $obs_scores;
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
	    observed_score,
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
	    $obs_scores = _unpack_scores($values[3]);
	    $exp_scores = _unpack_scores($values[4]);
	    $diff_scores = _unpack_scores($values[5]);
	} else {
	    $obs_scores = $values[3];
	    $exp_scores = $values[4];
	    $diff_scores = $values[5];
	}

	$conservation_score = new Bio::EnsEMBL::Compara::ConservationScore(
				        -adaptor => $self,
					-genomic_align_block_id => $values[0],
					-window_size => $values[1],
					-position => $values[2],
					-observed_score => $obs_scores,
					-expected_score => $exp_scores,
					-diff_score => $diff_scores,
					-packed => $packed);
	push(@$conservation_scores, $conservation_score);
    }
    
  #sort into numerical order based on position
  my @sorted_scores = sort {$a->{position} <=> $b->{position}} @$conservation_scores;
  return \@sorted_scores;
}

#find the min and max scores for y axis scaling
sub _find_min_max_score {
    my ($scores) = @_;
    my $min = $_no_score_value;
    my $max = $_no_score_value;

    foreach my $score (@$scores) {
	#find min and max of obs and exp scores
	if ($min > $score->diff_score) {
	    $min = $score->diff_score;
	}
	if ($max < $score->diff_score) {
	    $max = $score->diff_score;
	}
    }
    return ($min, $max);
}

#reverse the conservation scores for complemented sequences
sub _reverse {
    my ($scores) = @_;

    #reverse each conservation_score 
    foreach my $s (@$scores) {
	$s->reverse;
    }
    #reverse array so position values go from small to large
    my @rev = reverse @$scores;

    return \@rev;
}

#unpack scores.
sub _unpack_scores {
    my ($scores) = @_;
    if (!defined $scores) {
	return "";
    }
    my $num_scores = length($scores)/$_pack_size;

    my $score = "";
    for (my $i = 0; $i < $num_scores * $_pack_size; $i+=$_pack_size) {
	my $value = substr $scores, $i, $_pack_size;
	$score .= unpack($_pack_type, $value) . " ";
    }
    return $score;
}


#find the score index (row) that contains $pos in alignment coords
#use global variable $_score_index to keep track of where I am in the scores 
#array
#$scores : array of conservation scores
#$num_scores : number of scores in the array
#$score_lengths : number of scores in each row of the array
#$pos : position to find
#$win_size : window size used from the database
sub _find_score_index {
    my ($scores, $num_scores, $score_lengths, $pos, $win_size) = @_;
    my $i;
    my $length;

    #special case for first window size 
    if ($pos < $scores->[0]->position && $pos > ($scores->[0]->position - $win_size)) {
	return 0;
    }
    
    for ($i = $_score_index; $i < $num_scores; $i++) {
	$length = ($score_lengths->[$i] - 1) * $win_size;

	if ($pos >= $scores->[$i]->position && $pos <= $scores->[$i]->position + $length) {
	    $_score_index = $i;
	    return ($i);
	}

	#smaller than end so there is no score for this position
	if ($pos < ($scores->[$i]->position + $length)) {
	    $_score_index = $i;
	    return -1;
	}
    }
    return -1;
}

#print scores (unpack first if necessary)
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
	    $end = (length($scores->[$cnt]->observed_score) / 4);
	} else {
	    @values = split ' ', $scores->[$cnt]->diff_score;
	    $end = scalar(@values);
	}
	print "row $cnt length $end\n";
	$total_scores += $end;
	for ($i = 0; $i < $end; $i++) {
	    my $score;
	    if ($packed) {
		my $value = substr $scores->[$cnt]->observed_score, $i*$_pack_size, $_pack_size;
		$score = unpack($_pack_type, $value);
	    } else {
		$score = $values[$i];
	    }
	    print "$i score $score \n";
	}
    }
    print "Total $total_scores\n";

}

#Convert conservation scores from alignment coordinates into species specific
#chromosome coordinates for an alignment genomic_align_block
#
#cigar_line: cigar string from current alignment block
#start_region: start of genomic_align_block (chr coords)
#end_region: end of genomic_align_block (chr coords)
#start_slice: start of slice (chr coords)
#end_slice: end of slice (chr coords)
#scores: array of conservation_score objects in alignment coords
#genomic_align_block_id: genomic align block id of current alignment block
#genomic_align_block_length: length of current alignment block
#display_type: either AVERAGE or MAX (plot average or max value)
#win_size: window size used from database
#aligned_scores:array of new conservation_scores in chromosome coords
sub _get_aligned_scores_from_cigar_line {
    my ($self, $cigar_line, $start_region, $end_region, $start_slice, $end_slice, $scores, $genomic_align_block_id, $genomic_align_block_length, $display_type, $win_size, $aligned_scores) = @_;

    return undef if (!$cigar_line);
    
    my $num_aligned_scores = scalar(@$aligned_scores);
    my @cig = ( $cigar_line =~ /(\d*[GMD])/g );

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
	my $length;
	if ($PACKED) {
	    $length = length($scores->[$j]->diff_score)/$_pack_size;
	} else {
	    my @split_scores = split ' ', $scores->[$j]->diff_score;
	    $length = scalar(@split_scores);
	}
	push (@$score_lengths, $length);
    }

    #fill in region between previous alignment and this alignment with uncalled values
    if ($num_aligned_scores > 0) {
	my $prev_chr_pos = $_bucket->{start_seq_region_pos}+$_bucket->{cnt};
	for (my $i = $prev_chr_pos; $i < $chr_start; $i++) {
	    $aligned_score = _add_to_bucket($self, $display_type, $_no_score_value, $i, $start_slice, scalar(@$aligned_scores), $genomic_align_block_id, $win_size);
	    
	    if ($aligned_score) {
		push(@$aligned_scores, $aligned_score);
	    }
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
	if( $cigType eq "M" ) {
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
    for ($current_pos = $align_start; $current_pos <= $align_end && $chr_pos <= $chr_end; $current_pos += $win_size) {

	#find conservation score row index containing current_pos. Returns -1
	#if no score found
	$cs_index = _find_score_index($scores, $num_scores, $score_lengths, $current_pos, $win_size);

	#if a score has been found, find the score in the score string and 
	#unpack it.
	unless ($cs_index == -1) {
	    $csBlockCnt = int(($current_pos - $scores->[$cs_index]->position)/$win_size);

	    my $value;
	    if ($PACKED) {
		$value = substr $scores->[$cs_index]->diff_score, $csBlockCnt*$_pack_size, $_pack_size;
		$diff_score = unpack($_pack_type, $value);
	    } else {
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
	    
	    $total_pos += $cigLength;
	    if( $cigType eq "M" ) {
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
		$aligned_score = _add_to_bucket($self, $display_type, $_no_score_value, $chr_pos, $start_slice, scalar(@$aligned_scores), $genomic_align_block_id, $win_size);
		if ($aligned_score) {
		    push(@$aligned_scores, $aligned_score);
		}
	    } else {
		#in cigar match and have conservation score
		$aligned_score = _add_to_bucket($self, $display_type, $diff_score, $chr_pos, $start_slice, scalar(@$aligned_scores), $genomic_align_block_id, $win_size);
		if ($aligned_score) {
		    push(@$aligned_scores, $aligned_score);
		}
	    }
	} else {
	    #not in cigar match so only add the next conservation score or
	    #_no_score_value if this isn't a score
	    if ($prev_position != $chr_pos) {
		if ($cs_index == -1) {
		    $aligned_score = _add_to_bucket($self, $display_type, $_no_score_value, $chr_pos, $start_slice, scalar(@$aligned_scores), $genomic_align_block_id, $win_size);
		    if ($aligned_score) {
			push(@$aligned_scores, $aligned_score);
		    }
		} else {
		    $aligned_score = _add_to_bucket($self, $display_type, $diff_score, $chr_pos, $start_slice, scalar(@$aligned_scores), $genomic_align_block_id, $win_size);
		    if ($aligned_score) {
			push(@$aligned_scores, $aligned_score);
		    }
		}
	    }
	}
	$prev_position = $chr_pos;
    }

    return $aligned_scores;
}

sub _get_alignment_scores {
    my ($self, $conservation_scores, $display_type, $window_size, $genomic_align_block) = @_;

    my $num_rows = scalar(@$conservation_scores);
    my @diff_scores;
    my $diff_score;
    my $aligned_scores = [];
    my $pos;

    #if first pos is not at the start of the alignment (1) then need to fill in
    #with _no_score_value
    $pos = $conservation_scores->[0]->position;
    my $genomic_align_block_id = $genomic_align_block->dbID;
    for (my $j = 1; $j < $pos; $j+=$window_size) {
	
	my $aligned_score = _add_to_bucket($self, $display_type, $_no_score_value, $j, 1, scalar(@$aligned_scores), $genomic_align_block_id, $window_size);  
	if ($aligned_score) {
	    push(@$aligned_scores, $aligned_score);
	}
    }

    for (my $i = 0; $i < $num_rows; $i++) {
	my $num_scores;
	if ($PACKED) {
	    $num_scores = length($conservation_scores->[$i]->diff_score)/$_pack_size;
	} else {
	    @diff_scores = split ' ', $conservation_scores->[$i]->diff_score;
	    $num_scores = scalar(@diff_scores);
	}
	$pos = $conservation_scores->[$i]->position;

	for (my $j = 0; $j < $num_scores; $j++) {

	    if ($PACKED) {
		my $value = substr $conservation_scores->[$i]->diff_score, $j*$_pack_size, $_pack_size;
		$diff_score = unpack($_pack_type, $value);
	    } else {
		$diff_score = $diff_scores[$j];
	    } 

	    my $aligned_score = _add_to_bucket($self, $display_type, $diff_score, $pos, 1, scalar(@$aligned_scores), $genomic_align_block_id, $window_size);  
	    if ($aligned_score) {
		push(@$aligned_scores, $aligned_score);
	    }
	    $pos+=$window_size;
	}
	my $next_pos;
	if ($i < $num_rows-1) {
	    $next_pos = $conservation_scores->[$i+1]->position;
	} else {
	    $next_pos = $genomic_align_block->length;
	}
	for (my $j = $pos; $j < $next_pos; $j+=$window_size) {
	    
	    my $aligned_score = _add_to_bucket($self, $display_type, $_no_score_value, $j, 1, scalar(@$aligned_scores), $genomic_align_block_id, $window_size);  
	    if ($aligned_score) {
		push(@$aligned_scores, $aligned_score);
	    }
	}
    }
    return $aligned_scores;
}

#Add scores to bucket until it is full (given by size) and then average the 
#called scores or take the maximum (given by display_type). Once the bucket is
#full, create a new conservation score object
#Return the conservation score object if the bucket is full or 0 if it isn't
#full yet
#
#display_type : either "AVERAGE" or "MAX"
#score : score to be added to bucket
#chr_pos : position in slice reference species chromosome coords
#start_slice : start position of slice in chromosome coords
#num_buckets : number of buckets used so far
#genomic_align_block_id : genomic_align_block_id of alignment block
#win_size : window size used from database
#
#bucket structure:
#cnt: keep track of number of scores been added
#start_pos: position of first score in slice coords
#start_seq_region_pos: position of first score in chr coords
#diff_score: sum or max of difference scores
#called: number of called scores (used to average)
#size: number of bases/bucket
sub _add_to_bucket {
    my ($self, $display_type, $score, $chr_pos, $start_slice, $num_buckets, $genomic_align_block_id, $win_size) = @_;
    my $p = 0;
    my $s;
    my $final_score;

    #store start of bucket position
    if ($_bucket->{cnt} == 0) {

	$_bucket->{start_pos} = $chr_pos - $start_slice + 1;
	$_bucket->{start_seq_region_pos} = $chr_pos;

	#initialise diff_score for new bucket
	if ($display_type eq "AVERAGE") {
	    $_bucket->{diff_score} = 0;
	} else {
	    $_bucket->{diff_score} = $score;
	}
    }

    #convert chr_pos into slice coords
    my $end_pos = $chr_pos - $start_slice + 1;

    my $end_seq_region_pos = $chr_pos;

    if ($display_type eq "AVERAGE") {

	#store the scores
	if ($score != $_no_score_value) {
	    $_bucket->{diff_score} += $score;
	    $_bucket->{called}++;
	}

	$_bucket->{cnt}++;

	#check to see if reached size of bucket NB end_pos is in slice coords
	#so multiply size (number of bases/bucket) by number of buckets used so
	#far (plus 1 because it starts at 0)
	if ($end_pos >= ($_bucket->{size} * ($num_buckets+1))) {

	    #take average position 
	    $p = int(($end_pos + $_bucket->{start_pos})/2);
	    $s = int(($end_seq_region_pos + $_bucket->{start_seq_region_pos})/2);
	    #take average score
	    if ($_bucket->{called} == 0) {
		$final_score  = $_no_score_value;
	    } else {
		#should average over complete bucket even if not all values are
		#called
		#$final_score = $_bucket->{diff_score}/$_bucket->{called};
		$final_score = $_bucket->{diff_score}/$_bucket->{cnt};
	    }
	}
    } else {
	#store only the max score
	if ($_bucket->{diff_score} < $score) {
	    $_bucket->{diff_score} = $score;
	}
	$_bucket->{cnt}++;
	if ($end_pos >= ($_bucket->{size} * ($num_buckets+1))) {
	    $p = int(($end_pos + $_bucket->{start_pos})/2);
	    $s = int(($end_seq_region_pos + $_bucket->{start_seq_region_pos})/2);
	    $final_score = $_bucket->{diff_score};
	}
    }

    #if bucket is full, create a new conservation score
    #if ($end_pos >= ($_bucket->{size} * ($num_buckets+1))) {
    if (defined $final_score) {

	my $aligned_score = new Bio::EnsEMBL::Compara::ConservationScore(
		      -adaptor => $self,
		      -genomic_align_block_id => $genomic_align_block_id,
		      -window_size => $win_size,
		      -position => $p,
		      -seq_region_pos => $s,
		      -diff_score => $final_score,
		      );
	$_bucket->{diff_score} = 0;
	$_bucket->{cnt} = 0;
	$_bucket->{called} = 0;
	return $aligned_score;
    }
    #return 0 if not filled bucket
    return 0;
}

1;

