
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

Bio::EnsEMBL::DBSQL::GenomicAlign - Alignment of two pieces of genomic DNA

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

use Bio::EnsEMBL::Compara::AlignBlock;
use Bio::EnsEMBL::Compara::AlignBlockSet;

# Object preamble - inherits from Bio::Root::RootI

use Bio::Root::RootI;

@ISA = qw(Bio::Root::RootI);

# new() is written here 

sub new {
    my($class,@args) = @_;
    
    my $self = {};
    bless $self,$class;
    
    my ($align_id,$adaptor) = $self->_rearrange([qw(ALIGN_ID ADAPTOR )],@args);

    if( !defined $align_id) {
	$self->throw("Must have align id for genomicalign");
    }

    if( !defined $adaptor) {
	$self->throw("Must have adaptor for genomicalign");
    }

    $self->align_id($align_id);
    $self->adaptor($adaptor);
    $self->{'_align_block'} = {};
    $self->_loaded_align_block(0);

# set stuff in self from @args
    return $self;
}


=head1 SimpleAlignOutputI compliant methods

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

   foreach my $abs ( values %{$self->{'_align_block'}} ) {
       my @alb = $abs->get_AlignBlocks;
       my $first = $alb[0];
       my $seq = Bio::LocatableSeq->new();
       $seq->display_id($first->raw_contig->id);
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

       $seq->primary_seq->seq($str);
       push(@out,$seq);

   }
   
   return @out;
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
   my $id = $self->align_id;
   my $sth = $self->adaptor->prepare("select align_row from genomic_align_block where align_id = '$id'");
   
   $sth->execute;
   my $align_row;
   while( ($align_row) = $sth->fetchrow_array ) {
       my $abs = $self->get_AlignBlockSet($align_row);
       $self->{'_align_block'}->{$align_row} = $abs;
   }
       
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







1;
