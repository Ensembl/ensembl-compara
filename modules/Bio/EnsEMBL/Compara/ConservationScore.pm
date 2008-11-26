#
# Ensembl module for Bio::EnsEMBL::Compara::ConservationScore
#
# Cared for by Kathryn Beal <kbeal@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::ConservationScore - Stores conservation scores

=head1 SYNOPSIS

use Bio::EnsEMBL::Compara::ConservationScore;
my $conservation_score = new Bio::EnsEMBL::Compara::ConservationScore(
    -genomic_align_block => $gab, 
    -window_size => $win_size, 
    -position => $pos, 
    -observed_score => $obs_scores, 
    -expected_score => $exp_scores, 
    -diff_score => $diff_scores);

SET VALUES
    $conservation_score->genomic_align_block($gab);
    $conservation_score->window_size(10);
    $conservation_score->position(1);
    $conservation_score->observed_score($observed_scores);
    $conservation_score->expected_score($expected_scores);
    $conservation_score->diff_score($diff_scores);
    $conservation_score->y_axis_min(0);
    $conservation_score->y_axis_max(100);


GET VALUES
    $gab = $conservation_score->genomic_align_block;
    $win_size = $conservation_score->window_size;
    $pos = $conservation_score->position;
    $obs_scores = $conservation_score->observed_score;
    $exp_scores = $conservation_score->expected_score;
    $diff_scores = $conservation_score->diff_score;
    $y_axis_min = $conservation_score->y_axis_min;
    $y_axis_max = $conservation_score->y_axis_max;

=head1 DESCRIPTION

Object for storing conservation scores. The scores are averaged over different
window sizes to speed up drawing over large regions. The scores are packed as 
floats and stored in a string. The scores can be stored and retrieved in 
either a packed or unpacked format. The unpacked format is as a space delimited
string eg ("0.123 0.456 0.789"). The packed format is a single precision float 
(4 bytes). It is recommended to use the unpacked format.

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


package Bio::EnsEMBL::Compara::ConservationScore;

use strict;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(warning deprecate throw);

#store as 4 byte float
my $pack_size = 4;
my $pack_type = "f";

=head2 new (CONSTRUCTOR)

    Arg [-ADAPTOR] 
        : Bio::EnsEMBL::Compara::DBSQL::ConservationScore $adaptor
                (the adaptor for connecting to the database)
    Arg [-GENOMIC_ALIGN_BLOCK] (opt)
        : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlock $genomic_align_block
        (the Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlock of the multiple
         alignment)
    Arg [-GENOMIC_ALIGN_BLOCK_ID] (opt) 
         : int $genomic_align_block_id
         (the database internal ID of the $genomic_align_block)
    Arg [-WINDOW_SIZE] (opt)
         : int $window_size
         (window size used to average the scores over)
    Arg [-POSITION] (opt)
        : int $position
        (position of the first score in alignment coordinates)
    Arg [-SEQ_REGION_POS] (opt)
        : int $seq_region_pos
        (position of the first score in species coordinates)
    Arg [-EXPECTED_SCORE]
        : string $expected_score
        (packed or unpacked string of expected scores)
    Arg [-DIFF_SCORE]
        : string $diff_score
        (packed or unpacked string of the difference between the observed and
	 expected scores)
    Arg [-PACKED] (opt)
        : boolean $packed
        (whether the scores are packed (1) or unpacked (0))
    Arg [Y_AXIS_MIN] (opt)
	: float $y_axis_min
	(minimum score value used for display)
    Arg [Y_AXIS_MAX] (opt)
	: float $y_axis_max
	(maximum score value used for display)
    Example :
	my $conservation_score = new Bio::EnsEMBL::Compara::ConservationScore(
				     -genomic_align_block => $gab, 
				     -window_size => $win_size, 
                                     -position => $pos, 
                                     -expected_score => $exp_scores, 
                                     -diff_score => $diff_scores);
       Description: Creates a new ConservationScore object
       Returntype : Bio::EnsEMBL::Compara::ConservationScore
       Exceptions : none
       Caller     : general
       Status     : At risk

=cut

sub new {

    my($class, @args) = @_;
  
    my $self = {};
    bless $self,$class;
    
    my ($adaptor, $genomic_align_block, $genomic_align_block_id,
	$window_size, $position, $seq_region_pos, 
	$expected_score, $diff_score, $packed, $y_axis_min, $y_axis_max) = 
	    rearrange([qw(
			  ADAPTOR GENOMIC_ALIGN_BLOCK GENOMIC_ALIGN_BLOCK_ID
			  WINDOW_SIZE POSITION SEQ_REGION_POS 
			  EXPECTED_SCORE DIFF_SCORE PACKED Y_AXIS_MIN 
			  Y_AXIS_MAX)],
		      @args);

    $self->adaptor($adaptor) if (defined($adaptor));
    $self->genomic_align_block($genomic_align_block) if (defined($genomic_align_block));
    $self->genomic_align_block_id($genomic_align_block_id) if (defined($genomic_align_block_id));
    $self->window_size($window_size) if (defined($window_size));
    $self->position($position) if (defined($position));
    $self->seq_region_pos($seq_region_pos) if (defined($seq_region_pos));

    $self->expected_score($expected_score) if (defined($expected_score));
    $self->diff_score($diff_score) if (defined($diff_score));

    $self->y_axis_min($y_axis_min) if (defined($y_axis_min));
    $self->y_axis_max($y_axis_max) if (defined($y_axis_max));

    if (defined($packed)) {
	$self->packed($packed);
    } else {
	$self->packed(0);
    }
    return $self;
}

=head2 new_fast

  Arg [1]    : hash reference $hashref
  Example    : none
  Description: This is an ultra fast constructor which requires knowledge of
               the objects internals to be used.
  Returntype :
  Exceptions : none
  Caller     :
  Status     : At risk

=cut

sub new_fast {
  my ($class, $hashref) = @_;

  return bless $hashref, $class;
}

=head2 adaptor

  Arg [1]    : Bio::EnsEMBL::DBSQL::ConservationScoreAdaptor $adaptor
  Example    : $conservation_score->adaptor($adaptor);
  Description: Getter/Setter for the adaptor this object used for database
               interaction
  Returntype : Bio::EnsEMBL::DBSQL::ConservationScoreAdaptor object
  Exceptions : thrown if the argument is not a
               Bio::EnsEMBL::DBSQL::ConservationScoreAdaptor object
  Caller     : general
  Status     : At risk

=cut

sub adaptor {
  my ( $self, $adaptor ) = @_;

  if (defined($adaptor)) {
    throw("$adaptor is not a Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor object")
        unless ($adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor"));
    $self->{'adaptor'} = $adaptor;
  }

  return $self->{'adaptor'};
}


=head2 genomic_align_block

  Arg [1]    : Bio::EnsEMBL::Compara::GenomicAlignBlock $genomic_align_block 
  Example    : my $genomic_align_block = $conservation_score->genomic_align_block();
  Example    : $conservation_score->genomic_align_block($genomic_align_block);
  Description: Getter/Setter for the genomic_align_block attribute
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object. If no
               argument is given, the genomic_align_block is not defined but
               if both the genomic_align_block_id and the adaptor are, it tries
               to fetch the data using the genomic_align_block_id.
  Exceptions : thrown if $genomic_align_block is not a 
               Bio::EnsEMBL::Compara::GenomicAlignBlock object or if 
               $genomic_align_block does not match a previously defined
               genomic_align_block_id
  Warning    : warns if getting data from other sources fails.
  Caller     : general
  Status     : At risk

=cut

sub genomic_align_block {
    my ($self, $genomic_align_block) = @_;
    
    if (defined($genomic_align_block)) {
	throw("$genomic_align_block is not a Bio::EnsEMBL::Compara::GenomicAlignBlock object")
	    unless ($genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));

	if ($self->{'genomic_align_block_id'}) {
	    throw("dbID of genomic_align_block object does not match previously defined".
            " genomic_align_block_id. If you want to override a".
            " Bio::EnsEMBL::Compara::ConservationScore object, you can reset the ".
		  "genomic_align_block_id using \$conservation_score->genomic_align_block_id(0)")
          if ($self->{'genomic_align_block'}->dbID != $self->{'genomic_align_block_id'});
	}
	$self->{'genomic_align_block'} = $genomic_align_block;
    } elsif (!defined($self->{'genomic_align_block'})) {
	# Try to get the genomic_align_block from other sources...
	if (defined($self->genomic_align_block_id) and defined($self->{'adaptor'})) {
	    # ...from the genomic_align_block_id. Uses genomic_align_block_id function
	    # and not the attribute in the <if> clause because the attribute can be retrieved from other
	    # sources if it has not been set before.
	    my $genomic_align_block_adaptor = $self->{'adaptor'}->db->get_GenomicAlignBlockAdaptor;
	    $self->{'genomic_align_block'} = $genomic_align_block_adaptor->fetch_by_dbID(
											 $self->{'genomic_align_block_id'});
	} else {
	    warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->genomic_align_block".
		    " You either have to specify more information (see perldoc for".
		    " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
	}
    }
    
    return $self->{'genomic_align_block'};
}

=head2 genomic_align_block_id

  Arg [1]    : (opt) integer genomic_align_block_id 
  Example    : my $genomic_align_block_id = $conservation_score->genomic_align_block_id();
  Example    : $conservation_score->genomic_align_block_id($genomic_align_block_id);
  Description: Getter/Setter for the genomic_align_block_id attribute. If no
               argument is given and the genomic_align_block_id is not defined,
               it tries to get the data from other sources like the 
               corresponding Bio::EnsEMBL::Compara::GenomicAlignBlock object or
               the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object.
  Returntype : integer
  Exceptions : thrown if $genomic_align_block_id does not match a previously 
               defined genomic_align_block 
  Warning    : warns if getting data from other sources fails.
  Caller     : general
  Status     : At risk

=cut

sub genomic_align_block_id {
    my ($self, $genomic_align_block_id) = @_;
    
    if (defined($genomic_align_block_id)) {
	$self->{'genomic_align_block_id'} = ($genomic_align_block_id or undef);
	if (defined($self->{'genomic_align_block'}) and $self->{'genomic_align_block_id'}) {
	    warning("Defining both genomic_align_block_id and genomic_align_block");
	    throw("genomic_align_block_id does not match previously defined genomic_align_block object")
		if ($self->{'genomic_align_block'} and
		    $self->{'genomic_align_block'}->dbID != $self->{'genomic_align_block_id'});
	}
    } elsif (!($self->{'genomic_align_block_id'})) {
	# Try to get the ID from other sources...
	if (defined($self->{'genomic_align_block'}) and defined($self->{'genomic_align_block'}->dbID)) {
	    # ...from the corresponding Bio::EnsEMBL::Compara::GenomicAlignBlock object
	    $self->{'genomic_align_block_id'} = $self->{'genomic_align_block'}->dbID;
	} elsif (defined($self->{'adaptor'}) and defined($self->{'dbID'})) {
	    # ...from the database using the dbID of the Bio::EnsEMBL::Compara::GenomicAlign object
	    $self->adaptor->retrieve_all_direct_attributes($self);
	} else {
	    warning("Fail to get data from other sources in Bio::EnsEMBL::Compara::GenomicAlign->genomic_align_block_id".
		    " You either have to specify more information (see perldoc for".
		    " Bio::EnsEMBL::Compara::GenomicAlign) or to set it up directly");
	}
    }
    return $self->{'genomic_align_block_id'};
}



=head2 window_size

  Arg [1]    : (opt) integer window_size
  Example    : my $window_size = $conservation_score->window_size();
  Example    : $conservation_score->window_size(1);
  Description: Getter/Setter for the window_size of this conservation score
  Returntype : integer, Returns 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub window_size {
    my ($self, $window_size) = @_;

    if(defined $window_size) {
	$self->{'window_size'} = $window_size;
    }
    $self->{'window_size'}='1' unless(defined($self->{'window_size'}));
    return $self->{'window_size'};
}

=head2 position

  Arg [1]    : (opt) integer
  Example    : $conservation_score->position(1);
  Description: Getter/Setter for the alignment position of the first score
  Returntype : integer. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub position {
    my ($self, $position) = @_;

    if(defined $position) {
	$self->{'position'} = $position;
    }

  $self->{'position'}='1' unless(defined($self->{'position'}));
  return $self->{'position'};
}

=head2 start

  Example    : $conservation_score->start();
  Description: Wrapper round position call 
  Returntype : integer. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub start {
    my $self = shift;
   return $self->position; 
}

=head2 end

  Example    : $conservation_score->end();
  Description: wrapper around position
  Returntype : integer. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub end {
    my $self = shift;
   return $self->position; 
}
=head2 seq_region_pos

  Arg [1]    : (opt) integer
  Example    : $conservation_score->seq_region_pos(1);
  Description: Getter/Setter for the species position of the first score
  Returntype : integer.
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub seq_region_pos {
    my ($self, $seq_region_pos) = @_;

    if(defined $seq_region_pos) {
	$self->{'seq_region_pos'} = $seq_region_pos;
    }

    return $self->{'seq_region_pos'};
}


=head2 observed_score

  Example    : my $obs_score = $conservation_score->observed_score();
  Description: Getter for the observed score string (no setter functionality)
  Returntype : double
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub observed_score {
    my ($self) = @_;
    return ($self->expected_score - $self->diff_score);
}


=head2 expected_score

  Arg [1]    : (opt) string of expected scores (can be either packed or space 
					        delimited)
  Example    : $conservation_score->expected_score("3.85 2.54 1.56");
  Example    : my $exp_score = $conservation_score->expected_score();
  Description: Getter/Setter for the expected score string
  Returntype : string (either packed or space delimited)
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub expected_score {
    my ($self, $expected_score) = @_;

    if (defined $expected_score) {
	$self->{'expected_score'} = $expected_score;
    }
    return $self->{'expected_score'};
}

=head2 diff_score

  Arg [1]    : (opt) string of difference scores (expected - observed)
               (can be either packed or space delimited)
  Example    : $conservation_score->diff_score("1.85 -2.54 1.56");
  Example    : my $diff_score = $conservation_score->diff_score();
  Description: Getter/Setter for the difference score string
  Returntype : string (either packed or space delimited)
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub diff_score {
    my ($self, $diff_score) = @_;

    if (defined $diff_score) {
	$self->{'diff_score'} = $diff_score;
    }
    return $self->{'diff_score'};
}

=head2 score

  Arg [1]    : (opt) string of difference scores (expected - observed)
               (can be either packed or space delimited)
  Example    : $conservation_score->diff_score("1.85 -2.54 1.56");
  Example    : my $diff_score = $conservation_score->diff_score();
  Description: alias for diff score 
  Returntype : string (either packed or space delimited)
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub score {
    my ($self, $diff_score) = @_;
    return $self->diff_score($diff_score);
}

=head2 y_axis_min

  Arg [1]    : (opt) float
  Example    : $conservation_score->y_axis_min(-0.5);
  Example    : $y_axis_min = $conservation_score->y_axis_min;
  Description: Getter/Setter for the minimum score
  Returntype : float
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub y_axis_min {
    my ($self, $y_axis_min) = @_;

    if (defined $y_axis_min) {
	$self->{'y_axis_min'} = $y_axis_min;
    }
    return $self->{'y_axis_min'};
}

=head2 y_axis_max

  Arg [1]    : (opt) float
  Example    : $conservation_score->y_axis_max(2.45);
  Example    : $y_axis_max = $conservation_score->y_axis_min;
  Description: Getter/Setter for the maximum score
  Returntype : float
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub y_axis_max {
    my ($self, $y_axis_max) = @_;

    if (defined $y_axis_max) {
	$self->{'y_axis_max'} = $y_axis_max;
    }
    return $self->{'y_axis_max'};
}

=head2 packed

  Arg [1]    : (opt) boolean 
  Example    : $conservation_score->packed(1);
  Example    : $packed = $conservation_score->packed;
  Description: Getter/Setter for the whether the scores are packed or space
               delimited
  Returntype : boolean
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub packed {
    my ($self, $packed) = @_;

    if($packed) {
	$self->{'packed'} = $packed;
    }
    return $self->{'packed'};
}

=head2 reverse

  Example    : $conservation_score->reverse;
  Description: reverse scores and position in the ConservationScore object
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub reverse {
    my ($self, $genomic_align_block_length) = @_;
    my $num_scores = 0;
    return if (!defined($self->score));
    if ($self->packed) { 
	$num_scores = length($self->score)/$pack_size;
    } else {
	my @scores = split ' ', $self->score;
	$num_scores = scalar(@scores);
    } 
    
    #swap position orientation and reverse position in alignment
    my $end = $self->position + (($num_scores - 1) * $self->window_size);
    #10.10.06 +1 so position starts at 1 not 0
    #$self->position($self->genomic_align_block->length - $end);
    if (!defined($genomic_align_block_length)) {
      $genomic_align_block_length = $self->genomic_align_block->length;
    }
    $self->position($genomic_align_block_length - $end + 1);

    #swap position orientation and reverse seq_region_pos in alignment
    if (defined $self->seq_region_pos) {
	$end = $self->seq_region_pos + (($num_scores - 1) * $self->window_size);
	#10.10.06 +1 so position starts at 1 not 0
	#$self->seq_region_pos($self->genomic_align_block->length - $end);
	$self->seq_region_pos($self->genomic_align_block->length - $end + 1);
    }

    #reverse score strings
    $self->expected_score(_reverse_score($self->expected_score, $num_scores, $self->packed));
    $self->diff_score(_reverse_score($self->diff_score, $num_scores, $self->packed));
}

=head2 _reverse_score

  Arg [1]    : string $score_str (string of scores)
  Arg [2]    : int $num_scores (number of scores in the string)
  Arg [3]    : boolean $packed (whether the scores are packed or not)

  Example    : _reverse_score($self->expected_score, $num_scores, $self->packed)
  Description: internal method used by reverse to reverse the score strings
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _reverse_score {
    my ($score_str, $num_scores, $packed) = @_;

    my $rev_str;
    if ($packed) { 
	for (my $i = $num_scores-1; $i >=0; $i--) {
	    my $value = substr $score_str, $i*$pack_size, $pack_size;
	    $rev_str .= $value;
	}
    } else {
	my @scores = split ' ', $score_str;
	my $rev_str;
	for (my $i = $num_scores-1; $i >= 0; $i--) {
	    $rev_str .= $scores[$i];	
	} 
    }
    return $rev_str;
}

=head2 _print

  Example    : $conservation_score->_print;
  Description: print the contents of the ConservationScore object
  Returntype : none
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _print {
  my ($self, $FILEH) = @_;

#  my $verbose = verbose;
#  verbose(0);
  my $exp_score = 0;
  if ($self->expected_score) {
      $exp_score = $self->expected_score;
  }
  
  $FILEH ||= \*STDOUT;
  
  print $FILEH

"Bio::EnsEMBL::Compara::GenomicAlignBlock object ($self)
  genomic_align_block = " . ($self->genomic_align_block) . "
  genomic_align_block_id = " . ($self->genomic_align_block_id) . "
  window_size = " . ($self->window_size) . "
  position = " . ($self->position) . "
  seq_region_pos = " . ($self->seq_region_pos) . "
  diff_score = " . ($self->diff_score) . "
  expected_score = $exp_score \n";

}

1;
