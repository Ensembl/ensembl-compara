
#
# Ensembl module for Bio::EnsEMBL::AlignBlock
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::AlignBlock - DESCRIPTION of Object

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


package Bio::EnsEMBL::Compara::AlignBlock;
use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::RootI

use Bio::Root::RootI;
use Bio::SeqFeatureI;
#use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Compara::DnaDnaAlignFeature;
use Bio::EnsEMBL::SeqFeature;

@ISA = qw(Bio::Root::RootI Bio::SeqFeatureI);

# new() is written here 

sub new {
  my($class,@args) = @_;

  my $self = {};
  bless $self,$class;
  
# set stuff in self from @args
  return $self;
}

=head2 start

 Title   : start
 Usage   : $obj->start($newval)
 Function: 
 Example : 
 Returns : value of start
 Args    : newvalue (optional)


=cut

sub start{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'start'} = $value;
    }
    return $obj->{'start'};

}

=head2 end

 Title   : end
 Usage   : $obj->end($newval)
 Function: 
 Example : 
 Returns : value of end
 Args    : newvalue (optional)


=cut

sub end{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'end'} = $value;
    }
    return $obj->{'end'};

}

=head2 align_start

 Title   : align_start
 Usage   : $obj->align_start($newval)
 Function: 
 Example : 
 Returns : value of align_start
 Args    : newvalue (optional)


=cut

sub align_start{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'align_start'} = $value;
    }
    return $obj->{'align_start'};

}

=head2 align_end

 Title   : align_end
 Usage   : $obj->align_end($newval)
 Function: 
 Example : 
 Returns : value of align_end
 Args    : newvalue (optional)


=cut

sub align_end{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'align_end'} = $value;
    }
    return $obj->{'align_end'};

}


=head2 strand

 Title   : strand
 Usage   : $obj->strand($newval)
 Function: 
 Example : 
 Returns : value of strand
 Args    : newvalue (optional)


=cut

sub strand{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'strand'} = $value;
    }
    return $obj->{'strand'};

}


=head2  perc_id

 Title   : perc_id 
 Usage   : $obj->perc_id($newval)
 Function:
 Example :
 Returns : identity (in percentage) 
 Args    : newvalue (optional)


=cut

sub perc_id{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'perc_id'} = $value;
    }
    return $obj->{'perc_id'};

}

=head2 score 

 Title   : score 
 Usage   : $obj->score($newval)
 Function:
 Example :
 Returns : identity (in percentage)
 Args    : newvalue (optional)


=cut

sub score{
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'score'} = $value;
    }
    return $obj->{'score'};

}

=head2 cigar_string

 Title   : cigar_string
 Usage   : $obj->cigar_string($newval)
 Function:
 Example :
 Returns : string (cigar_string representing the alignment)
 Args    : newvalue (optional)


=cut

sub cigar_string {
   my ($obj,$value) = @_;
   if( defined $value) {
      $obj->{'cigar_string'} = $value;
    }
    return $obj->{'cigar_string'};

}

=head2 dnafrag

 Title   : dnafrag
 Usage   : $obj->dnafrag($newval)
 Function: 
 Example : 
 Returns : value of dnafrag
 Args    : newvalue (optional)


=cut

sub dnafrag{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'dnafrag'} = $value;
    }
    return $self->{'dnafrag'};

}

=head2 return_DnaDnaAlignFeature

 Title   : return_DnaDnaAlignFeature
 Usage   : $obj->return_DnaDnaAlignFeature
 Function: 
 Example : 
 Returns : value of a Bio::EnsEMBL::Compara::DnaDnaAlignFeature object
 Args    : none

=cut

sub return_DnaDnaAlignFeature {
  my ($self,$align_name) = @_;
  my $DnaDnaAlignFeature = new Bio::EnsEMBL::Compara::DnaDnaAlignFeature('-cigar_string' => $self->cigar_string);
  my $feature1 = new Bio::EnsEMBL::SeqFeature;
  $feature1->seqname($align_name);
  $feature1->start($self->align_start);
  $feature1->end($self->align_end);
  $feature1->strand(1);
  my $feature2 = new Bio::EnsEMBL::SeqFeature;
  $feature2->seqname($self->dnafrag->name);
  $feature2->start($self->start);
  $feature2->end($self->end);
  $feature2->strand($self->strand);
  $DnaDnaAlignFeature->feature1($feature1);
  $DnaDnaAlignFeature->feature2($feature2);
  $DnaDnaAlignFeature->score($self->score);
  $DnaDnaAlignFeature->percent_id($self->perc_id);
  return $DnaDnaAlignFeature;
}

=head2 SeqFeatureI compliant methods

=head2 seq

 Title   : seq
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub seq{
   my ($self) = @_;

   my $seq = $self->entire_seq->trunc($self->start(), $self->end());

   if ( $self->strand == -1 ) {
       $seq = $seq->revcom;
   }
   return $seq;
}

=head2 entire_seq

 Title   : entire_seq
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub entire_seq{
   my ($self,@args) = @_;

   return $self->dnafrag->contig->db_primary_seq;
}

=head2 primary_tag

 Title   : primary_tag
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub primary_tag{
   my ($self,@args) = @_;

   return 'align';
}

=head2 source_tag

 Title   : source_tag
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub source_tag{
   my ($self,@args) = @_;

   return 'ensembl';
}

=head2 all_tags

 Title   : all_tags
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub all_tags{
   my ($self,@args) = @_;

   return ('primary_tag','source_tag');
}

=head2 has_tag

 Title   : has_tag
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub has_tag{
   my ($self,@args) = @_;

   return 0;
}

