#
# Ensembl module for Bio::EnsEMBL::Compara::GenomicAlign
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::GenomicAlign - Alignment of two pieces of genomic DNA

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR - Ewan Birney

This modules is part of the Ensembl project http://www.ensembl.org

Email birney@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::GenomicAlign;
use vars qw(@ISA);
use strict;

# Object preamble

use Bio::EnsEMBL::Root;

@ISA = qw(Bio::EnsEMBL::Root);

# new() is written here 

sub new {
    my($class,@args) = @_;

    my $self = {};
    bless $self,$class;

    my ( $consensus_dnafrag, $consensus_start, $consensus_end,
	 $query_dnafrag, $query_start, $query_end, $query_strand,$alignment_type,
	 $score, $perc_id, $cigar_line, $adaptor ) = 
      $self->_rearrange([qw(CONSENSUS_DNAFRAG CONSENSUS_START CONSENSUS_END
                            QUERY_DNAFRAG QUERY_START QUERY_END
			    QUERY_STRAND ALIGNMENT_TYPE SCORE PERC_ID CIGAR_LINE
			    ADAPTOR )],@args);

    $self->adaptor( $adaptor ) if defined $adaptor;
    $self->consensus_dnafrag( $consensus_dnafrag ) if defined $consensus_dnafrag;
    $self->consensus_start( $consensus_start ) if defined $consensus_start;
    $self->consensus_end( $consensus_end ) if defined $consensus_end;
    $self->query_dnafrag( $query_dnafrag ) if defined $query_dnafrag;
    $self->query_start( $query_start ) if defined $query_start;
    $self->query_end( $query_end ) if defined $query_end;
    $self->query_strand( $query_strand ) if defined $query_strand;
    $self->alignment_type( $alignment_type ) if defined $alignment_type;
    $self->score( $score ) if defined $score;
    $self->perc_id( $perc_id ) if defined $perc_id;
    $self->cigar_line( $cigar_line ) if defined $cigar_line;

    return $self;
}


sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
}


=head2 adaptor

  Arg [1]    : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor
  Example    : $adaptor = $genomic_align->adaptor;
  Description: Getter/Setter for the adaptor this object uses for database
               interaction.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor
  Exceptions : none
  Caller     : general

=cut

sub adaptor{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'adaptor'} = $value;
    }
    return $obj->{'adaptor'};
}


=head2 consensus_dnafrag
 
  Arg [1]    : Bio::EnsEMBL::Compara::DnaFrag $consensus_dnafrag
  Example    : none
  Description: get/set for attribute consensus_dnafrag_id
  Returntype : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Exceptions : none
  Caller     : general
 
=cut

sub consensus_dnafrag {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'consensus_dnafrag'} = $arg ;
   }
   return $self->{'consensus_dnafrag'};
}



=head2 consensus_start
 
  Arg [1]    : int $consensus_start
  Example    : none
  Description: get/set for attribute consensus_start
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub consensus_start {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'consensus_start'} = $arg ;
   }
   return $self->{'consensus_start'};
}



=head2 consensus_end
 
  Arg [1]    : int $consensus_end
  Example    : none
  Description: get/set for attribute consensus_end
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub consensus_end {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'consensus_end'} = $arg ;
   }
   return $self->{'consensus_end'};
}



=head2 query_dnafrag
 
  Arg [1]    : Bio::EnsEMBL::Compara::DnaFrag $query_dnafrag
  Example    : none
  Description: get/set for attribute query_dnafrag
  Returntype : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Exceptions : none
  Caller     : general
 
=cut

sub query_dnafrag {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'query_dnafrag'} = $arg ;
   }
   return $self->{'query_dnafrag'};
}



=head2 query_start
 
  Arg [1]    : int $query_start
  Example    : none
  Description: get/set for attribute query_start
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub query_start {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'query_start'} = $arg ;
   }
   return $self->{'query_start'};
}



=head2 query_end
 
  Arg [1]    : int $query_end
  Example    : none
  Description: get/set for attribute query_end
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub query_end {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'query_end'} = $arg ;
   }
   return $self->{'query_end'};
}


=head2 query_strand
 
  Arg [1]    : int $query_strand
  Example    : none
  Description: get/set for attribute query_strand
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub query_strand {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'query_strand'} = $arg ;
   }
   return $self->{'query_strand'};
}


=head2 alignment_type
 
  Arg [1]    : string $alignment_type
  Example    : 'WGA' or 'WGA_HCR'
  Description: get/set for attribute alignment_type
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub alignment_type {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'alignment_type'} = $arg ;
   }
   return $self->{'alignment_type'};
}

=head2 score
 
  Arg [1]    : double $score
  Example    : none
  Description: get/set for attribute score  
  Returntype : double
  Exceptions : none
  Caller     : general
 
=cut

sub score {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'score'} = $arg ;
   }
   return $self->{'score'};
}



=head2 perc_id
 
  Arg [1]    : int $perc_id
  Example    : none
  Description: get/set for attribute perc_id  
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub perc_id {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'perc_id'} = $arg ;
   }

   $self->{'perc_id'} = "NULL" unless (defined $self->{'perc_id'});

   return $self->{'perc_id'};
}

=head2 cigar_line
 
  Arg [1]    : string $cigar_line
  Example    : none
  Description: get/set for attribute cigar_line  
  Returntype : string
  Exceptions : none
  Caller     : general
 
=cut

sub cigar_line {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'cigar_line'} = $arg ;
   }
   return $self->{'cigar_line'};
}

=head2 group_id
 
  Arg [1]    : int $group_id
  Example    : none
  Description: get/set for attribute group_id
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub group_id {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'group_id'} = $arg ;
   }
   return $self->{'group_id'};
}

=head2 level_id
 
  Arg [1]    : int $level_id
  Example    : none
  Description: get/set for attribute level_id
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub level_id {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'level_id'} = $arg ;
   }
   return $self->{'level_id'};
}

=head2 strands_reversed
 
  Arg [1]    : int $strands_reversed
  Example    : none
  Description: get/set for attribute strands_reversed
               0 means that strand and hstrand are the original strands obtained
                 from the alignment program used
               1 means that strand and hstrand have been flipped as compared to
                 the original result provided by the alignment program used.
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut

sub strands_reversed {
   my ($self, $arg) = @_;
 
   if ( defined $arg ) {
      $self->{'strands_reversed'} = $arg ;
   }

   $self->{'strands_reversed'} = 0 unless (defined $self->{'strands_reversed'});

   return $self->{'strands_reversed'};
}

=head2 alignment_strings

  Arg [1]    : list of string $flags
               FIX_SEQ = does not introduce gaps (dashes) in seq (consensus) aligned sequence
                         and delete the corresponding insertions in hseq aligned sequence
               FIX_HSEQ = does not introduce gaps (dashes) in hseq (query) aligned sequence
                         and delete the corresponding insertions in seq aligned sequence
               NO_SEQ = return the seq (consensus) aligned sequence as an empty string
               NO_HSEQ = return the hseq (query) aligned sequence as an empty string
               This 2 last flags would save a bit of time as doing so no querying to the core
               database in done to get the sequence.
  Example    : $ga->alignment_strings or
               $ga->alignment_strings("FIX_HSEQ") or
               $ga->alignment_strings("NO_SEQ","FIX_SEQ")
  Description: Allows to rebuild the alignment string of both the seq (consensus) and 
               hseq (query) sequence using the cigar_string information and the slice 
               and hslice objects
  Returntype : array reference containing 2 strings
               the first corresponds to seq (consensus)
               the second corresponds to hseq (query)
  Exceptions : 
  Caller     : 

=cut

sub alignment_strings {
  my ( $self, @flags ) = @_;

  # set the flags
  my $seq_flag = 1;
  my $hseq_flag = 1;
  my $fix_seq_flag = 0;
  my $fix_hseq_flag = 0;

  for my $flag ( @flags ) {
    $seq_flag = 0 if ($flag eq "NO_SEQ");
    $hseq_flag = 0 if ($flag eq "NO_HSEQ");
    $fix_seq_flag = 1 if ($flag eq "FIX_SEQ");
    $fix_hseq_flag = 1 if ($flag eq "FIX_HSEQ");
  } 

  my ($seq, $hseq);
  $seq = $self->consensus_dnafrag->slice->subseq($self->consensus_start, $self->consensus_end) if ($seq_flag || $fix_seq_flag);
  $hseq = $self->query_dnafrag->slice->subseq($self->query_start, $self->query_end, $self->query_strand) if ($hseq_flag || $fix_hseq_flag);

  my $rseq= "";
  # rseq - result sequence
  my $rhseq= "";
  # rhseq - result hsequence

  my $seq_pos = 0;
  my $hseq_pos = 0;

  my @cig = ( $self->cigar_line =~ /(\d*[DIM])/g );

  for my $cigElem ( @cig ) {
    my $cigType = substr( $cigElem, -1, 1 );
    my $cigCount = substr( $cigElem, 0 ,-1 );
    $cigCount = 1 unless $cigCount;

    if( $cigType eq "M" ) {
        $rseq .= substr( $seq, $seq_pos, $cigCount ) if ($seq_flag);
        $rhseq .= substr( $hseq, $hseq_pos, $cigCount ) if ($hseq_flag);
      $seq_pos += $cigCount;
      $hseq_pos += $cigCount;
    } elsif( $cigType eq "D" ) {
      if( ! $fix_seq_flag ) {
        $rseq .=  "-" x $cigCount if ($seq_flag);
        $rhseq .= substr( $hseq, $hseq_pos, $cigCount ) if ($hseq_flag);
      }
      $hseq_pos += $cigCount;
    } elsif( $cigType eq "I" ) {
      if( ! $fix_hseq_flag ) {
        $rseq .= substr( $seq, $seq_pos, $cigCount ) if ($seq_flag);
        $rhseq .= "-" x $cigCount if ($hseq_flag);
      }
      $seq_pos += $cigCount;
    }
  }
  return [ $rseq,$rhseq ];
}

1;
