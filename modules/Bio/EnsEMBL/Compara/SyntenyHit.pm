
# Cared for by Tania
#
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Protein_Hit - Object representing one Protein_Hit (for synteny) 

=head1 SYNOPSIS

    # $db is Bio::EnsEMBL::DB::Obj 

     my $protein_hit = Bio::EnsEMBL::SyntenyHit->new (-dbID       => $dbID,  
                                                       -align_id    => $align_id,
                                                       -dnafrag_id=> $dnafrag_id,
                                                       -adaptor   => $adaptor
                                                     );


=head1 DESCRIPTION

This is just a lite weight object which is used to store results from our genomic align block and other tables so that we
can populate our synteny region tables



=head1 CONTACT

kailan (calan@imcb.nus.edu.sg)
tania (tania@fugu-sg.org)

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::SyntenyHit;
use vars qw(@ISA);

use strict;

# Object preamble

use Bio::EnsEMBL::Root;

@ISA = qw(Bio::EnsEMBL::Root);

# new() is written here

sub new {
  my($class,@args) = @_;

  my $self = $class->SUPER::new(@args);
 

  my ($dbID, $align_id, $dnafrag_id, $adaptor) = $self->_rearrange([qw(DBID 
                                                                    ALIGN_ID
                                                                    DNAFRAG_ID 
                                                                    ADAPTOR
                                                                    )], @args);
  if( defined $dbID) {
	$self->dbID($dbID);
   }
   if( defined $align_id) {
     $self->align_id($align_id);
   }

   if (defined $dnafrag_id){
     $self->dnafrag_id($dnafrag_id);
   }

   if (defined $adaptor){
     $self->adaptor($adaptor);
   }
    

# set stuff in self from @args
  return $self;
}

=head2 align_id 

 Title	 : align_id 
 Usage	 : $obj->align_id($newval)
 Function:
 Example :
 Returns : value of align_id
 Args	 : newvalue (optional)


=cut

sub align_id {
	my ($obj,$value) = @_;
	if( defined $value) {
	$obj->{'align_id'} = $value;
    }
	return $obj->{'align_id'};

}


=head2 dnafrag_id

 Title	 : dnafrag_id
 Usage	 : $obj->dnafrag_id($newval)
 Function:
 Example :
 Returns : value of dnafrag_id
 Args	 : newvalue (optional)


=cut

sub dnafrag_id{
	my ($obj,$value) = @_;
	if( defined $value) {
	$obj->{'dnafrag_id'} = $value;
    }
	return $obj->{'dnafrag_id'};

}

=head2 dbID

 Title	 : dbID
 Usage	 : $obj->dbID($newval)
 Function: 
 Example : 
 Returns : value of dbID
 Args 	 : newvalue (optional)


=cut

sub dbID{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'dbID'} = $value;
    }
    return $self->{'dbID'};

}

=head2 adaptor

 Title	 : adaptor
 Usage	 : $obj->adaptor($newval)
 Function: 
 Example : 
 Returns : value of adaptor
 Args 	 : newvalue (optional)


=cut

sub adaptor{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'adaptor'} = $value;
    }
    return $self->{'adaptor'};

}
   
1;
