
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

@ISA = qw(Bio::Root::RootI);

sub new {
    my ($class,@args) = @_;

    my $self = {};
    bless $self,$class;

	my ($dbID, $external_id,,$proteinDB,$seq_start,$seq_end,$strand,$dnafrag,$adaptor) = 
			$self->_rearrange([qw(	DBID
                                    EXTERNAL_ID
                                    PROTEINDB
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
	if (defined $proteinDB){
		$self->proteinDB($proteinDB);
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

=head2 proteinDB

 Title   : proteinDB
 Usage   : $obj->proteinDB(val)
 Function:
 Returns : proteinDB obj associated with this Protein
 Args    : newvalue (optional)

=cut

sub proteinDB{
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'proteinDB'} = $value;
   }
   return $self->{'proteinDB'};

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

