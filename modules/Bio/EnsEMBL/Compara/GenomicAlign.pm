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



=head2 sequence_align_string

  Arg  1     : Bio::EnsEMBL::Slice $consensus_slice
               A slice covering the conensus area of this alignment
  Arg  2     : Bio::EnsEMBL::Slice $query_slice
               A slice covering the query_area of this alignment
  Arg  3..   : list of String $flags
               FRAG_SLICES = slices cover the dna frags
               ALIGN_SLICES = slices cover just the aligned area
               FIX_CONSENSUS = dont put dashes in consensus sequence on 
               alignment printout
               FIX_QUERY = dont put dashes in query sequence on alignment
               CONSENSUS = return the consensus aligned sequence
               QUERY = return the query aligned sequence
  Example    : none
  Description: returns representations of the aligned sequences according to
               the flags.
  Returntype : String
  Exceptions : none
  Caller     : general

=cut


sub sequence_align_string {
  my ( $self, $consensus_slice, $query_slice, @flags ) = @_;

  my ( $cseq, $qseq );
  my @cig = ( $self->cigar_line() =~ /(\d*[DIM])/g );

  # set the flags
  my ( $consensus, $query, $fix_consensus, $fix_query, $align_slices,
       $frag_slices );

  for my $flag ( @flags ) {
    if( $flag eq "CONSENSUS" ) { $consensus = 1 }
    elsif( $flag eq "QUERY" ) { $query = 1 }
    elsif( $flag eq "FIX_CONSENSUS" ) { $fix_consensus = 1 }
    elsif( $flag eq "FIX_QUERY" ) { $fix_query = 1 }
    elsif( $flag eq "ALIGN_SLICES" ) { $align_slices = 1 }
  } 
  
  # here fill cseq and qseq with the aligned area sequence

  if( $align_slices ) {
    $cseq = $consensus_slice->seq();
    $qseq = $query_slice->seq();
  } else {
    $cseq = $consensus_slice->subseq( $self->consensus_start(),
                                      $self->consensus_end(), 1 );
    $qseq = $query_slice->subseq( $self->query_start(),
				  $self->query_end(), $self->query_strand() );
  }

  my $rseq= "";
  # rseq - result sequence

  my ( $cigCount, $cigType );
  my ( $cpos, $qpos );
  $cpos = 0; $qpos = 0;

  for my $cigElem ( @cig ) {
    $cigType = substr( $cigElem, -1, 1 );
    $cigCount = substr( $cigElem, 0 ,-1 );
    $cigCount = 1 unless $cigCount;

    if( $cigType eq "M" ) {
      if( $consensus ) {
        $rseq .= substr( $cseq, $cpos, $cigCount );
      } else {
        $rseq .= substr( $qseq, $qpos, $cigCount );
      }
      $cpos += $cigCount;
      $qpos += $cigCount;
    } elsif( $cigType eq "D" ) {
      if( $consensus ) {
        if( ! $fix_consensus ) {
          $rseq .=  "-" x $cigCount;
        }
      } else {
        if( ! $fix_consensus ) {
          $rseq .= substr( $qseq, $qpos, $cigCount );
        }
      }

      $qpos += $cigCount;
    } elsif( $cigType eq "I" ) {
      if( $consensus ) {
        if( ! $fix_query ) {
          $rseq .= substr( $cseq, $cpos, $cigCount );
        }
      } else {
        if( ! $fix_query ) {
          $rseq .= "-" x $cigCount;
        }
      }
     
      $cpos += $cigCount;
    }
  }     
  return $rseq;
}



1;
