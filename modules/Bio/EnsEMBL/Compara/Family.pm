
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

use Bio::Root::Root;
use Bio::EnsEMBL::Compara::Protein;

@ISA = qw(Bio::Root::Root);

=head2 new

 Title   : new 
 Usage   : $obj->new($newval)
 Function:
 Returns : value of new 
 Args    : newvalue (optional)
 Comments:
		  Creates a new family object with the option of using 
		  --lazy fetching (just fetching list of protein_ids, objects fetched only when using get_all_members or get_members_by_db)
		  --industrious fetching (load the protein objects into the family. Mainly useful for doing loading of databases)
		  use the --lazyfetching [T/F] option, defaults to T
 

=cut

sub new {
    my ($class,@args) = @_;
    my $self = {};
    bless $self,$class;
    my ($dbID,$stable_id,$threshold,$adaptor,$description,$annot_score,$members) = $self->_rearrange([qw(
																										DBID
																										STABLEID
																										THRESHOLD
																										ADAPTOR
																										DESCRIPTION
																										ANNOTATIONSCORE
																										MEMBERS
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
    if (defined $annot_score){
		$self->annotation_score($annot_score);
    }
	if (defined $members){
		$self->add_members(@$members);
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
	  $obj->throw("$value not a Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor") unless $value->isa("Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor");
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

=head2 annotation_score

 Title	 : annotation_score
 Usage	 : $obj->annotation_score($newval)
 Function: Getset for annotation_score object
 Returns : value of annotation-score 
 Args	 : newvalue(optional)

=cut

sub annotation_score{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
	$obj->{'annotation_score'} = $value;
    }
    return $obj->{'annotation_score'};

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
 my ($self, $name) = @_; 
 	#don't worry about caching...this is done in get_members_of_db
	if (defined $name){
		my $size = scalar($self->get_members_of_db($name));
		return $size;
	}
 	else { 
		return scalar($self->get_all_members);
	}

}

=head2 add_members

 Title   : add_members
 Usage   : $fam->add_members
 Function: returns the number of members of the family
 Returns : an array of family members
 Args : a Bio::EnsEMBL::Compara::Protein obj 

=cut

sub add_members {
	my ($self,@fam_protein) = @_;
 	 
	foreach my $fam_protein (@fam_protein){
		my $id;
		if (ref($fam_protein) eq "HASH"){ #a protein id
			if ($fam_protein->isa("Bio::EnsEMBL::Compara::Protein")){
				$self->_proteins_loaded(1);
				$id = $fam_protein->external_id;
			}
		}
		elsif($self->_proteins_loaded){

		}
		else {
			$self->_proteins_loaded(0);
			$id = $fam_protein;
		}	
				 
   		if(!$self->exist($fam_protein)){ #check whether familyprotein already exists
			my @prot;
			push @prot, $fam_protein;
			$self->_members(@prot);
#   			push @{$self->{_members}},$fam_protein;
   		}
	    else {
			$self->warn("Protein with ID:".$id." already exists!");
		}
	}
   return $self->members;
   
}
sub _proteins_loaded{
	my ($self,$load) = @_;
	if (defined $load){
		$self->{'_proteins_loaded'} = $load;
	}
	return $self->{'_proteins_loaded'};
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
	
	foreach my $mem ($self->_members){
		if (!$mem->isa("Bio::EnsEMBL::Compara::Protein")){ #members are identifiers
			if ($mem eq $famprot){
				return 1;
			}
		}
		elsif ($mem->external_id eq $famprot->external_id){#members are proteins
			return 1;
		}
		else{}
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
	if (!$self->proteins_loaded){
		$self->get_all_members;
	}
	$self->warn("No member of from $dbname") unless (scalar($self->_members_of_db($dbname) > 0));
	return $self->_members_of_db($dbname);
}	

=head2 members

 Title   : members
 Usage   : $fam->members
 Function: get all members of the family which belong to a specified db
 Returns : an array of Bio::EnsEMBL::Compara::Protein
 Args    : optional, an array of Bio::EnsEMBL::Compara::Protein 

=cut

sub _members {
    my ($self,@proteins)=@_;
    if (!defined ($self->{'_members'})){
        $self->{'_members'} = {};
    }
	if (@proteins){
		foreach my $prot(@proteins){ #store hashed by dbname
			if (ref($prot) eq ""){
				push @{$self->{'_members'}{$prot}},$prot;
			}
			else {
				push @{$self->{'_members'}{$prot->external_dbname}},$prot;
			}
			
		}			
	}
	#looping through to return all members..this is to avoid storing another has with all
	#the proteins
	my @mems;
	foreach my $key (keys %{$self->{'_members'}}){
		push @mems,@{$self->{'_members'}{$key}};
	}
    return @mems; 
}
sub _members_of_db {
	my($self,$dbname) = @_;
	return $self->{'_members'}{$dbname};
}
=head2 get_all_members

 Title	 : get_all_members
 Usage	 : $fam->get_all_members
 Function: get all members of the family which belong to a specified db
 Returns : an array of Bio::EnsEMBL::Compara::Protein
 Args	 : a string specifying the database name

=cut

sub get_all_members {
	my ($self)=@_;
	if ($self->_proteins_loaded){
		return $self->_members;
	}
	elsif($self->adaptor){	
		#reuse function to fetch family with loaded proteins;
		my $family = $self->adaptor->fetch_by_dbID($self->dbID,"F");
		$self->_proteins_loaded(1);
		return $self->_members($family->get_all_members());	
	}
	else {
		$self->warn("No members for this family ".$self->dbID);
		return undef;
	}
}	

=head2 create_alignment

 Title	 : create_alignment
 Usage	 : $fam->create_alignment
 Function: creates an multiple alignment object using TCoffee or ClustalW
 Returns : a Bio::SimpleAlign 
 Args	 : $type : "clustalw" or "tcoffee", 
           @params of the form  @params = ('ktuple' => 2, 'matrix' => 'BLOSUM');  

=cut

sub create_alignment{
	my ($self,$type,@params) = @_;
	if (!defined(@params)){
		@params = ('matrix' => 'BLOSUM');	
	}
	require Bio::Tools::Run::Alignment::Clustalw;
	my $factory = Bio::Tools::Run::Alignment::Clustalw->new(@params);	
	my @proteins = $self->get_all_members;
	my @bioseq;
	foreach my $prot (@proteins){
		push @bioseq, $prot->seq();
	}
	my $aln = $factory->align(\@bioseq);
	$self->alignment($type,$aln);
	return $aln;
	
}

=head2 alignment 

 Title	 : alignment 
 Usage	 : $fam->alignment
 Function: store a SimpleAlign object 
 Returns :
 Args	 :$type (clustalw or tcoffee), Bio::SimpleAlign 

=cut

sub alignment {
   my ($self,$type,$aln) = @_;
   
   if (defined ($aln)){
	if ($aln->isa("Bio::SimpleAlign")){
		$self->{'_alignment'}{"$type"} = $aln;
		return $self->{'_alignment'}{"$type"};
	}
	else {
		$self->throw("Require a Bio::SimpleAlign object");
	}
   }
   elsif (defined ($type)){
	return $self->{'_alignment'}{"$type"};
   }
   else {
	return $self->{'_alignment'}{"clustalw"};
   }
}
	
=head2 store_alignment 

 Title   : store_alignment
 Usage   : $fam->store_alignment
 Function: store a SimpleAlign object into the database 
 Returns :  
 Args    : Bio::SimpleAlign, string ("clustalw or tcoffee") 

=cut

sub store_alignment {
	my ($self,$aln,$type) = @_;
	$self->throw("[$aln] is not a Bio::SimpleAlign obj!") unless $aln->isa("Bio::SimpleAlign");
	$type = "clustalw" unless defined ($type);
	
	$self->adaptor->store_alignment($self,$aln,$type);
}
	
sub create_tree {
}

=head2 get_alignment_by_type 

 Title	 : get_alignment_by_type 
 Usage	 : $obj->get_alignment_by_type($type)
 Function: retrieve a Bio::SimpleAlign object repsenting an alignment
 Returns : Bio::SimpleAlign 
 Args	 : type (string to specify type of alignment to get. e.g. clustalw,tcoffee)

=cut
sub get_alignment_by_type{
	my ($self, $type) = @_;
	return $self->adaptor->get_alignment_by_type($self,$type);
}

=head2 get_all_alignments

 Title	 : get_all_alignments
 Usage	 : $obj->get_all_alignments
 Function: retrieve an array of Bio::SimpleAlign objects repsenting an alignment
 Returns : array of Bio::SimpleAlign
 Args	 : 

=cut
sub get_all_alignments {
	 my ($self) = @_;
	 return $self->adaptor->get_all_alignments($self);
}

=head2 alignment_types

 Title   : alignment_types
 Usage   : $obj->alignment_types
 Function: retrieve an array of strings
 Returns : 
 Args    : 

=cut

sub alignment_types {

  my ($self) =  @_;
  return $self->adaptor->adaptor->get_alignment_types($self);
  

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
	$self->{'_created'} = $value;
   }
   return $self->{'_created'};

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
	$self->{'_modified'} = $value;
   }
   return $self->{'_modified'};

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
	$self->{'_version'} = $value;
   }
   return $self->{'_version'};

}

