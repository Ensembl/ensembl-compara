
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

# Object preamble - inheriets from Bio::Root::Root

use Bio::Root::Root;
#to change to Root once we migrate to new ensembl
use Bio::EnsEMBL::Compara::Protein;
use Bio::Tools::Run::Phylo::Phylip::Neighbor;
use Bio::Tools::Run::Phylo::Phylip::ProtPars;
use Bio::Tools::Run::Phylo::Phylip::ProtDist;

@ISA = qw(Bio::Root::Root);

=head2 new

 Title   : new 
 Usage   : $obj->new($newval)
 Function:
 Returns : value of new 
 Args    : newvalue (optional)
 Comments:
		  Creates a new family object. The members option takes in the following:
			a protein id
			a Bio::EnsEMBL::Compara::Protein object
			an array ref of an array of protein ids
			an array ref of an array of Bio::EnsEMBL::Compara::Protein objects 
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
		$self->add_members($members);
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
	if (defined $name){
		my $size = scalar($self->adaptor->nbr_members_of_db($self->dbID,$name));
		return defined($size) ? $size:0;
	}
 	else { 
		return scalar($self->_members);
	}

}
	
=head2 add_members

 Title   : add_members
 Usage   : $fam->add_members
 Function: returns the number of members of the family
 Returns : an array ref of protein ids/protein objects or a single protein id/protein object 
 Args : a Bio::EnsEMBL::Compara::Protein obj 

=cut

sub add_members {
	my ($self,$fam_protein) = @_;
 	 
	return $self->_members($fam_protein);

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
 	if (ref($famprot) eq ""){
		$self->{'_exist'}{$famprot} = 1;
	}
	elsif( $famprot->isa("Bio::EnsEMBL::Compara::Protein") && ($self->{'_exist'}{mem->external_id} eq 1)){#members are proteins
			return 1;
	}
	else{
		$self->throw("Don't know what we have here $famprot");
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
	
	if (!$self->_proteins_loaded){
		if ($self->adaptor){
			return $self->adaptor->fetch_members_by_dbname($self->dbID,$dbname);
		}
		return ();
	}
	$self->warn("No member of family dbID ".$self->dbID. " from $dbname") unless (scalar($self->_members_of_db($dbname) > 0));
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
    my ($self,$proteins)=@_;
    if (!defined ($self->{'_members'})){
        $self->{'_members'} = {};
    }
	if (defined $proteins){
		if (ref($proteins) ne "ARRAY"){
		
			if (ref($proteins) eq "Bio::EnsEMBL::Compara::Protein"){
				$self->_proteins_loaded(1);
				if (!$self->exist($proteins->external_id)){
					push @{$self->{'_members'}{$proteins->external_dbname}},$proteins;
				}
				$self->exist($proteins->external_id);
			}
			else {
				$self->_proteins_loaded(0);
				if (!$self->exist($proteins)){
					push @{$self->{'_members'}{'unloaded'}}, $proteins;	
				}
				$self->exist($proteins);
			}
		}
		else {
			if (ref(@{$proteins}->[0]) eq "Bio::EnsEMBL::Compara::Protein"){
				$self->_proteins_loaded(1);
				foreach my $prot(@{$proteins}){ #store hashed by dbname
						$self->throw("Not a Bio::EnsEMBL::Compara::Protein object") unless $prot->isa("Bio::EnsEMBL::Compara::Protein");
						#hash by the exeternal_db_name for ease of returing members by dbname
						push @{$self->{'_members'}{$prot->external_dbname}},$prot;
						#set the hash that this protein exists to avoid looping through all the members to check existence 
						$self->exist($prot->external_id);
				}			
				$self->{'_members'}{'unloaded'}=();
			}
			else {
				$self->_proteins_loaded(0);
				foreach my $prot (@{$proteins}){
					push @{$self->{'_members'}{'unloaded'}}, $prot;
				}
			}
		}
	}	
	#combine proteins from all the dbs and return
	my @mems;
	if ($self->_proteins_loaded){
		foreach my $key (keys %{$self->{'_members'}}){
			if ($key !~/unloaded/){
				push @mems,@{$self->{'_members'}{$key}};
			}
		}
		return @mems;
	}
	else {
		if (defined ($self->{'_members'}{"unloaded"})){
   		 	return @{$self->{'_members'}{"unloaded"}}; 
		}
		else {
			return ();
		}

	}
}

sub _members_of_db {
	my($self,$dbname) = @_;
	if (ref($self->{'_members'}{$dbname}) eq "ARRAY"){
		return @{$self->{'_members'}{$dbname}};
	}
	else {
		return ();
	}
	
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
	    my @prots = $family->_members;
		
		return $self->_members(\@prots);	
	}
	else {
		$self->warn("No members for this family ".$self->dbID);
		return ();
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
	my ($self,@params) = @_;
	if (!defined(@params)){
		@params = ('matrix' => 'BLOSUM');	
	}
	require Bio::Tools::Run::Alignment::Clustalw;
	my $factory = Bio::Tools::Run::Alignment::Clustalw->new(@params);	
	my @proteins = $self->get_all_members;
	my $aln = $factory->align(\@proteins);
	$self->alignment($aln);
	return $aln;
	
}
sub create_alignment_by_member_type {
	my ($self,@args) = @_;
	my ($type,$dbname,$params) = $self->_rearrange([qw(
													TYPE
													DBNAME
													PARAMS
													)],@args);
    if (!defined ($params)){
	     @{$params} = ('matrix' => 'BLOSUM');
    }

	my @prots;

	if (ref($dbname) eq "ARRAY"){
		foreach my $db (@{$dbname}){
			my @mems = $self->get_members_of_db($db);
			if ($#mems >  -1){
				push @prots, @mems;
			}
			else {
				$self->warn("No members found for $db");
			}
		}
		if (scalar(@prots) < 2){
			$self->warn("No enough members to do a alignment");
			return;
		}
	}
	else{	
		my @mems = $self->get_members_of_db($dbname);
		if (@mems){
			push @prots, @mems;
		}
		else {
			$self->throw("No members found for $dbname. Cannot do alignment");
		}
	}
	require Bio::Tools::Run::Alignment::Clustalw;
  my $factory = Bio::Tools::Run::Alignment::Clustalw->new(@{$params});
  my $aln = $factory->align(\@prots);
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
  my ($self,$aln) = @_;
   
  if (defined ($aln)){
    if ($aln->isa("Bio::SimpleAlign")){
      $self->{'_alignment'} = $aln;
		  return $self->{'_alignment'};
	  }
  	else {
	  	$self->throw("Require a Bio::SimpleAlign object");
	  }
  }
	return $self->{'_alignment'};
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


=head2 create_tree

 Title   : create_tree
 Usage   : $obj->create_tree('-program'=>'neighbor','params'=>\@params) 
 Function: creates a Bio::Tree object either through neighbor or protpars programs.Defaults to protpars.
 Returns : Bio::Tree
 Args    :  

=cut
sub create_tree {
  my ($self,@args) = @_;
  my ($program,$params) = $self->_rearrange([qw(PROGRAM PARAMS)],@args);

  if ($program =~/NEIGHBOR/i){
      my $matrix = $self->protdist_matrix();
      if (ref($matrix) eq "HASH"){
        my $neigh_factory =  Bio::Tools::Run::Phylo::Phylip::Neighbor->new(@$params);
        my $tree = $neigh_factory->create_tree($matrix);
        $self->tree($tree);
        return $tree;
      }
      else {
        $self->throw('Cannot create tree using neighbor unless you have a distance matrix. Run $fam->create_distance_matrix(@params) first.');
      }
  }
  else {
      my $aln = $self->alignment();
      if (ref($aln) eq "Bio::SimpleAlign"){
          my $protpars_factory = Bio::Tools::Run::Phylo::Phylip::ProtPars->new(@$params);
          my $tree = $protpars_factory->create_tree($aln);
          $self->tree($tree);
          return $tree;
      }
      else {
          $self->throw('Cannot create tree using protpars unless you have an alignment. Run $fam->create_alignment first.');
      }
  }
}

=head2 tree

 Title   : tree
 Usage   : $obj->tree('params'=>\@params) 
 Function: get/set for storing tree 
 Returns : Bio::Tree 
 Args    : Bio:Tree 

=cut

sub tree {
    my($self,$tree) = @_;
    if (defined($tree) && $tree->isa("Bio::Tree")){
        $self->{'_family_tree'} = $tree;
    }
    return $tree;
}


=head2 create_distance_matrix

 Title   : create_distance_matrix
 Usage   : $obj->create_distance_matrix('params'=>\@params) 
 Function: creates a matrix of protein distances stored in a hash of a hash.
 Returns : a hash ref 
 Args    :  

=cut

sub create_distance_matrix {
    my ($self,@params) = @_;
    my $protdist_factory = Bio::Tools::Run::Phylo::Phylip::ProtDist->new(@params);
    my $aln = $self->alignment;
    if (ref($aln) eq "Bio::SimpleAlign"){
      my $matrix = $protdist_factory->create_distance_matrix($aln);
      return $self->protdist_matrix($matrix);
    }
    else {
      $self->throw('Need a Bio::SimpleAlign object to use protdist. Run $fam->create_alignment(@params) first.');
    }
}

=head2 protdist_matrix 

 Title   : protdist_matrix
 Usage   : $obj->protdist_matrix($matrix) 
 Function: getset for storing matrix 
 Returns : a hash ref 
 Args    :  

=cut

sub protdist_matrix {
    my ($self,$matrix) = @_;
    if (ref($matrix) eq "HASH"){
      $self->{'distance_matrix'} = $matrix;
    }
    return $self->{'distance_matrix'};
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

