
#
# EnsEMBL module for Bio::EnsEMBL::Compara::Protein
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::Protein 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::Protein;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::RootI

use Bio::Root::RootI;

@ISA = qw(Bio::PrimarySeq);

sub new {
    my ($class,@args) = @_;

    my $self = {};
    bless $self,$class;

	my ($dbID, $external_id,,$external_dbname,$seq_start,$seq_end,$strand,$dnafrag,$adaptor) = 
			$self->_rearrange([qw(	DBID
                                    EXTERNAL_ID
                                    EXTERNAL_DBNAME
                                    SEQ_START
                                    SEQ_END
                                    STRAND
                                    DNAFRAG
                                    ADAPTOR)],@args);


	if (defined $dbID){
		$self->dbID($dbID);
	}
	if (defined $external_id){
		$self->external_id($external_id);
	}else {$self->thow("Protein must have an external_id");}

	if (defined $external_dbname){
		$self->external_dbname($external_dbname);
	}
	if (defined $seq_start){
		$self->seq_start($seq_start);
	}
	if (defined $seq_end){
		$self->seq_end($seq_end);
	}
	if (defined $strand){
		$self->strand($strand);
	}
	if (defined $dnafrag){
		$self->dnafrag($dnafrag);
	}
	if (defined $adaptor){
		$self->adaptor($adaptor);
	}

	return $self;
}


=head2 dbID

 Title   : dbID
 Usage   : $obj->dbID($newval)
 Function:
 Returns : value of dbID
 Args    : newvalue (optional)

=cut

sub dbID {
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'dbID'} = $value;
   }
   return $self->{'dbID'};

}

=head2 peptide_sequence_id

 Title   : peptide_sequence_id
 Usage   : $obj->peptide_sequence_id($newval)
 Function:
 Returns : value of peptide_sequence_id
 Args    : newvalue (optional)

=cut

sub peptide_sequence_id{
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'peptide_sequence_id'} = $value;
   }
   return $self->{'peptide_sequence_id'};

}

=head2 external_dbname

 Title   : external_dbname
 Usage   : $obj->external_dbname($newval)
 Function:
 Returns : value of external_dbname
 Args    : newvalue (optional)

=cut

sub external_dbname{
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'external_dbname'} = $value;
   }
   return $self->{'external_dbname'};

}

=head2 external_id

 Title   : external_id
 Usage   : $obj->external_id($newval)
 Function:
 Returns : value of external_id, reference id to another database
 Args    : newvalue (optional)

=cut

sub external_id {
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'external_id'} = $value;
   }
   return $self->{'external_id'};

}

=head2 stable_id

 Title   : stable_id
 Usage   : $obj->stable_id($newval)
 Function:
 Returns : value of stable_id, an ensembl stable identifier
 Args    : newvalue (optional)

=cut

sub stable_id{
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'stable_id'} = $value;
   }
   return $self->{'stable_id'} ;

}

=head2 seq
 
 Title   : seq
 Usage   : $string    = $obj->seq()
 Function: Returns the sequence as a string of letters.
 Returns : A scalar
 Args    : none
 
=cut
 
sub seq {
   my ($self,$value) = @_;
 
   if (defined $value) {
     if(! $self->validate_seq($value)) {
           $self->throw("Attempting to set the sequence to [$value] which does not look healthy");
       }
     $self->{'seq'} = $value;
   }
   if (! exists ($self->{'seq'})){
     $self->throw("No ProteinAdaptor attached to this Protein object. Can't fetch peptide sequence");
     $self->{'seq'} = $self->adaptor->fetch_peptide_seq($self->peptide_sequence_id);
   }
   return $self->{'seq'};
}


=head2 seq_start
 Title   : seq_start
 Usage   : $obj->seq_start($newval) 
 Function: getset for seq_start value
 Returns : value of seq_start
 Args    : newvalue (optional)

=cut

sub seq_start{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'seq_start'} = $value;
   }
   return $self->{'seq_start'};

}

=head2 seq_end
 Title   : seq_end
 Usage   : $obj->seq_end($newval) 
 Function: getset for seq_end value
 Returns : value of seq_end
 Args    : newvalue (optional)

=cut

sub seq_end{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'seq_end'} = $value;
   }
   return $self->{'seq_end'};

}

=head2 strand
 Title   : strand
 Usage   : $obj->strand($newval) 
 Function: getset for strand value
 Returns : value of strand
 Args    : newvalue (optional)

=cut

sub strand{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'strand'} = $value;
   }
   return $self->{'strand'};

}

=head2 seq
 
 Title   : seq
 Usage   : $seq = $obj->seq()
 Function: Returns the sequence as a Bio::PrimarySeq obj.
 Returns : Bio::PrimarySeq
 Args    : none
 
=cut
 
sub seq {
   my ($self) = @_;

   if (!defined $self->{'seq'}){
        $self->{'seq'} = $self->proteinDB->fetch_peptide_seq($self->external_id);
  }
   return $self->{'seq'};
 
}

=head2 dnafrag
 Title   : dnafrag
 Usage   : $obj->dnafrag($newval) 
 Function: getset for dnafrag
 Returns : Bio::EnsEMBL::Compara::dnafrag object
 Args    : Bio::EnsEMBL::Compara::dnafrag

=cut

sub dnafrag{
   my ($self,$value) = @_;

   if (defined $value){ 
     $self->throw("Trying to store $value as a Bio::EnsEMBL::Compara::DnaFrag!") unless $value->isa('Bio::EnsEMBL::Compara::DnaFrag') ;
   $self->{'dnafrag'} = $value;
   }
   return $self->{'dnafrag'};

}

=head2 adaptor

 Title   : adaptor
 Usage   : $obj->adaptor($newval)
 Function: Getset for adaptor object
 Returns : Bio::EnsEMBL::Compara::DBSQL::ProteinAdaptor
 Args    : Bio::EnsEMBL::Compara::DBSQL::ProteinAdaptor


=cut

sub adaptor{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'adaptor'} = $value;
    }
    return $obj->{'adaptor'};

}

# The following get/set methods store and fetches the protein's family properties


=head2 family_id

 Title   : family_id
 Usage   : $obj->family_id($newval)
 Function: Getset for protein's Family ID
 Returns : int , family dbID
 Args    : 


=cut

sub family_id{
   my ($self,$value) = @_;

   if(defined $value) {
      $self->{'family_id'} = $value;
    }
    return $self->{'family_id'};

}

=head2 family_score

 Title   : family_score
 Usage   : $obj->family_score($newval)
 Function: Getset for protein's Family score
 Returns : value
 Args    : 


=cut

sub family_score{
   my ($self,$value) = @_;

   if(defined $value) {
      $self->{'score'} = $value;
   } 
    return $self->{'score'};

}


1;
