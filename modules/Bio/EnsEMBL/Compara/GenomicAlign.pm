#
# Ensembl module for Bio::EnsEMBL::DBSQL::GenomicAlign
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
	 $query_dnafrag, $query_start, $query_end, $query_strand,
	 $score, $perc_id, $cigar_line, $adaptor ) = 
      $self->_rearrange([qw(CONSENSUS_DNAFRAG CONSENSUS_START CONSENSUS_END
                            QUERY_DNAFRAG QUERY_START QUERY_END
			    QUERY_STRAND SCORE PERC_ID CIGAR_LINE
			    ADAPTOR )],@args);

    $self->adaptor( $adaptor ) if defined $adaptor;
    $self->consensus_dnafrag( $consensus_dnafrag ) if defined $consensus_dnafrag;
    $self->consensus_start( $consensus_start ) if defined $consensus_start;
    $self->consensus_end( $consensus_end ) if defined $consensus_end;
    $self->query_dnafrag( $query_dnafrag ) if defined $query_dnafrag;
    $self->query_start( $query_start ) if defined $query_start;
    $self->query_end( $query_end ) if defined $query_end;
    $self->query_strand( $query_strand ) if defined $query_strand;
    $self->score( $score ) if defined $score;
    $self->perc_id( $perc_id ) if defined $perc_id;
    $self->cigar_line( $cigar_line ) if defined $cigar_line;

    return $self;
}


=head1 SimpleAlignOutputI compliant methods

=cut


sub each_seq {
    my $self = shift;

    return $self->eachSeq;
}


=head2 eachSeq

 Title   : eachSeq
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub eachSeq{
   my ($self,@args) = @_;

   my @out;

   $self->_ensure_loaded;
   my $count = 1;
   foreach my $abs ( values %{$self->{'_align_block'}} ) {
       my @alb = $abs->get_AlignBlocks;
       my $first = $alb[0];
       my $seq = Bio::LocatableSeq->new();
       $seq->display_id("ensembl".$count);
       $count++;
       $seq->start($first->start);
       $seq->end($alb[$#alb]->end);

       # loop over each block, getting out the sequence. Between blocks,
       # figure out how many '---' to assign using the align_start/end
       my $prev;
       my $str = "";
       foreach my $alb ( @alb ) {
	   if( defined $prev && $prev->align_end+1 != $alb->align_start ) {
	       if( $prev->align_end+1 > $alb->align_start ) {
		   $self->throw("Badly formatted align start/end...");
	       }
	       $str .= '-' x ($alb->align_start - $prev->align_end - 1);
	   }
	   $str .= $alb->seq->seq();
	   $prev = $alb;
       }

       $seq->seq($str);
       push(@out,$seq);

   }
   
   return @out;
}



=head2 each_AlignBlockSet

 Title   : each_AlignBlockSet
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub each_AlignBlockSet{
   my ($self,@args) = @_;

   $self->_ensure_loaded;

   return values %{$self->{'_align_block'}};

}


sub displayname {
    my ($self,@args) = @_;

    return $self->get_displayname(@args);
}

=head2 get_displayname

 Title   : get_displayname
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_displayname{
   my ($self,$nse) = @_;

   return $nse;
}

sub maxnse_length {
    return 50;
}

sub maxdisplayname_length {
    return 50;
}

sub length_aln {
   my $self = shift;

   my $abs = $self->get_AlignBlockSet(1);

   # assumme that first alignblockset is the reference
   my ($ab) = $abs->get_AlignBlocks();

   return $ab->align_end;
}

sub id {
  return "ensembl";
}

sub no_sequences {
  my $self = shift;

 return scalar($self->each_AlignBlockSet);
}


=head2 get_AlignBlockSet

 Title   : get_AlignBlockSet
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_AlignBlockSet{
   my ($self,$row) = @_;

   return $self->adaptor->get_AlignBlockSet($self->align_id,$row);
}

sub dbID {
    my ($self,$arg) = @_;

    return $self->align_id($arg);
}


=head2 align_id

 Title   : align_id
 Usage   : $obj->align_id($newval)
 Function: 
 Example : 
 Returns : value of align_id
 Args    : newvalue (optional)


=cut

sub align_id{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'align_id'} = $value;
    }
    return $obj->{'align_id'};

}

=head2 align_row_id

 Title   : align_row_id
 Usage   : $obj->align_row_id($newval)
 Function: 
 Example : 
 Returns : value of align_row_id
 Args    : newvalue (optional)


=cut

sub align_row_id{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'align_row_id'} = $value;
    }
    return $obj->{'align_row_id'};

}

=head2 align_name

 Title	 : align_name
 Usage	 : $obj->align_name($newval)
 Function: 
 Example : 
 Returns : value of align_name
 Args 	 : newvalue (optional)


=cut

sub align_name{
  my ($self,$value) = @_;
  if (defined $value) {
    $self->{'align_name'} = $value;
  }
  if (! defined $self->{'align_name'} &&
      defined $self->adaptor &&
      defined $self->align_id) {
    $self->{'align_name'} = $self->adaptor->fetch_align_name_by_align_id($self->align_id);
  }
  return $self->{'align_name'};
}

=head2 adaptor

 Title   : adaptor
 Usage   : $obj->adaptor($newval)
 Function: 
 Example : 
 Returns : value of adaptor
 Args    : newvalue (optional)


=cut

sub adaptor{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'adaptor'} = $value;
    }
    return $obj->{'adaptor'};

}

=head2 add_AlignBlockSet

 Title   : add_AlignBlockSet
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub add_AlignBlockSet{
   my ($self,$row_id,$abs) = @_;

   if( !defined $abs) {
       $self->throw("Cannot add AlignBlockSet without row_id,abs");
   }

   if( !ref $abs || !$abs->isa('Bio::EnsEMBL::Compara::AlignBlockSet') ) {
       $self->throw("Must have an AlignBlockSet, not a $abs");
   }

   $self->{'_align_block'}->{$row_id} = $abs;

}


=head2 _ensure_loaded

 Title   : _ensure_loaded
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub _ensure_loaded{
   my ($self,@args) = @_;

   if( $self->_loaded_align_block == 1) {
       return;
   }
   if( scalar( keys%{$self->{'_align_block'}}) > 0 ) {
       return;
   }

   $self->_load_all_blocks;
   $self->_loaded_align_block(1);
}



=head2 _load_all_blocks

 Title   : _load_all_blocks
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub _load_all_blocks{
   my ($self,@args) = @_;
   my $align_row_id = $self->align_row_id;
   my $abs = $self->get_AlignBlockSet($align_row_id);
   $self->add_AlignBlockSet($align_row_id,$abs);
}

=head2 _loaded_align_block

 Title   : _loaded_align_block
 Usage   : $obj->_loaded_align_block($newval)
 Function: 
 Example : 
 Returns : value of _loaded_align_block
 Args    : newvalue (optional)


=cut

sub _loaded_align_block{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'_loaded_align_block'} = $value;
    }
    return $obj->{'_loaded_align_block'};

}



### getters and setters ###



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


1;
