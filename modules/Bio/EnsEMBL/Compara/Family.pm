
#
# EnsEMBL module for Bio::EnsEMBL::Orthology::Family
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::Family 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::Family;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::RootI

use Bio::Root::RootI;
use Bio::EnsEMBL::Compara::Protein;
@ISA = qw(Bio::Root::RootI);

sub new {
    my ($class,@args) = @_;
    my $self = {};
    bless $self,$class;
    my ($dbID,$stable_id,$threshold,$adaptor,$description) = $self->_rearrange([qw(
									DBID
									STABLEID
									ADAPTOR
									DESCRIPTION
					     				)],@args);
    if (defined $dbID){
	$self->dbID($dbID);
    }
    if (defined $adaptor){
	$self->adaptor($adaptor);
    }
    if (defined $stable_id){
	$self->stable_id($stable_id);
    }
    if (defined $threshold){
	$self->threshold($threshold);
    }
    if (defined $description){
	$self->description($description);
    }



}


=head2 dbID

 Title   : dbID
 Usage   : $obj->dbID($newval)
 Function:
 Returns : value of dbID
 Args    : newvalue (optional)

=cut

sub dbID {
   my ($self,$value) = @_;
   if ($value){
      $self->{'dbID'} = $value;
   }
   return $self->{'dbID'};

}

=head2 stable_id

 Title	 : stable_id 
 Usage	 : $obj->stable_id($newval)
 Function:
 Returns : value of stable_id 
 Args	 : newvalue (optional)

=cut

sub stable_id{

   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'stable_id'} = $value;
   }
   return $self->{'stable_id'};

}

=head2 adaptor

 Title   : adaptor
 Usage   : $obj->adaptor($newval)
 Function: Getset for adaptor object
 Returns : Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor
 Args    : Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor

=cut

sub adaptor{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'adaptor'} = $value;
    }
    return $obj->{'adaptor'};

}

=head2 description

 Title	 : description
 Usage	 : $obj->description($newval)
 Function: Getset for description object
 Returns : value of descrition 
 Args	 : newvalue(optional)

=cut

sub description{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'description'} = $value;
    }
    return $obj->{'description'};

}

=head2 size

 Title   : size
 Usage   : $fam->size
 Function: returns the number of members of the family
 Returns : an int
 Args : optionally, a databasename; if given, only members belonging to
        that database are counted, otherwise, all are given.

=cut

sub size {
 my ($self, $db_name) = @_; 
 	if (defined $db_name) { 
		return scalar($self->get_members_of_db($db_name)); 
 	}
 	else { 
		return scalar($self->get_all_members());
	}

}

=head2 add_member

 Title   : add_member
 Usage   : $fam->add_member
 Function: returns the number of members of the family
 Returns : an array of family members
 Args : a Bio::EnsEMBL::Compara::Protein obj 

=cut

sub add_member {
   my ($self,$fam_protein) = @_;
   $self->throw("add_member currently only supports Bio::EnsEMBL::Compara::Protein") unless $fam_protein->isa('Bio::EnsEMBL::Compara::Protein');
   
   if(!$self->exist($fam_protein)){ #check whether familyprotein already exists
   	push @{$self->{_members}},$fam_protein;
   }
   else {
	$self->warn($fam_protein->dbID." already exists!");
   }
   return $self->get_all_members;
   
}

=head2 exist

 Title   : exist
 Usage   : $fam->exist
 Function: checks whether a particular Protein exists in the family
 Returns : an int
 Args    : Bio::EnsEMBL::Compara::Protein

=cut

sub exist {
	my ($self,$famprot) = @_;
	$self->throw("add_member currently only supports Bio::EnsEMBL::Compara::Protein") unless $fam_protein->isa('Bio::EnsEMBL::Compara::Protein');

	foreach my $mem ($self->get_all_members){
		if ($mem->dbID eq $famprot->dbID){
			return 1;
		}
	}
	return 0;
}

=head2 get_members_of_db

 Title	 : get_members_of_db
 Usage	 : $fam->get_members_of_db
 Function: get all members of the family which belong to a specified db 
 Returns : an array of Bio::EnsEMBL::Compara::Protein
 Args	 : a string specifying the database name

=cut

sub get_members_of_db {
	my ($self,$dbname)=@_;
	$self->throw("No database name specified for get_members_of_db ! ") unless defined($dbname):

	my @mems = ();
	foreach my $mem ($self->get_all_members){
		if ($mem->proteinDB->name eq $dbname){
			push @mems, $mem;
		}
	}
	return @mems;
}	

=head2 familyDB

 Title   : familyDB
 Usage   : $obj->familyDB(val)
 Function:
 Returns : familyDB obj associated with this Family 
 Args    : newvalue (optional)

=cut

sub familyDB{
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'familyDB'} = $value;
   }
   return $self->{'familyDB'};

}


=head2 threshold

 Title   : threshold
 Usage   : $obj->threshold($newval) 
 Function: getset for threshold value
 Returns : value of threshold
 Args    : newvalue (optional)

=cut

sub threshold{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'threshold'} = $value;
   }
   return $self->{'threshold'};

}

=head2 created

 Title	 : created
 Usage	 : $obj->created($newval)
 Function:
 Returns : value of created
 Args	 : newvalue (optional)

=cut

sub created{

   my $self = shift;
   if( @_ ) {
      my $value = shift;
	$self->{'created'} = $value;
   }
   return $self->{'created'};

}

=head2 modified

 Title	 : modified
 Usage	 : $obj->modified($newval)
 Function:
 Returns : value of modified
 Args	 : newvalue (optional)

=cut

sub modified{

   my $self = shift;
   if( @_ ) {
      my $value = shift;
	$self->{'modified'} = $value;
   }
   return $self->{'modified'};

}

=head2 version

 Title	 : version
 Usage	 : $obj->version($newval)
 Function:
 Returns : value of version
 Args	 : newvalue (optional)

=cut

sub version{

   my $self = shift;
   if( @_ ) {
      my $value = shift;
	$self->{'version'} = $value;
   }
   return $self->{'version'};

}

