#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor - DESCRIPTION of Object

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


package Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::Protein;
use Bio::EnsEMBL::Compara::Family;
use Bio::AlignIO;

@ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);


=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :
 this function does "lazy fetching" in that it only stores the list of member protein ids. 
 the actual protein object are fetched when called by get_all_members or get_members_by_db.

=cut

sub fetch_by_dbID{
	my ($self,$dbid,$lazyfetch) = @_;

	if( !defined $dbid) {
       $self->throw("Must fetch by dbid");
	}
	#get family info
	my $sth = $self->prepare("SELECT f.threshold,f.description,f.annotation_confidence_score FROM family f WHERE f.family_id = $dbid");
	$sth->execute;
	(my ($threshold,$description,$annot_score) = $sth->fetchrow_array()) or $self->throw("No family with this dbID $dbid");

	#get list of member proteins
	$sth = $self->prepare("select protein_id from family_protein where family_id = $dbid");
  	$sth->execute;
	my @proteins;	
	
	if ($lazyfetch eq "T" || !defined($lazyfetch)){
		while(my $prot = $sth->fetchrow_array()){
			push @proteins, $prot;
		}
	}
	else{ 
		#fetch objects instead. Heavy. Use lazyfetch where possible except maybe for loading databases
		while (my ($protein_id) = $sth->fetchrow_array()){
    		my $protein = $self->db->get_ProteinAdaptor->fetch_by_dbID($protein_id);
	    	$protein->family_id($dbid);
			push @proteins, $protein;
		}
	}
		
	#create the family
	my $family = Bio::EnsEMBL::Compara::Family->new(-dbid   => $dbid,
						                            -threshold => $threshold,
                        						    -description => $description,
						                            -annotationscore=>$annot_score,
						                            -adaptor => $self,
													-members => \@proteins);

    #set the family_stable_id if there exist one	
    $self->set_stable_entry_info($family);

	return $family;

}

=head2 get_stable_entry_info

 Title   : get_stable_entry_info
 Usage   : $famAdptor->get_stable_entry_info($fam)
 Function: gets stable info for gene and places it into the hash
 Returns : 
 Args    : 


=cut

sub set_stable_entry_info {
  my ($self,$fam) = @_;

  if( !defined $fam || !ref $fam || !$fam->isa('Bio::EnsEMBL::Compara::Family') ) {
     $self->throw("Needs Bio::EnsEMBL::Compara::Family, not a $fam");
  }

  my $sth = $self->prepare("select stable_id,UNIX_TIMESTAMP(created),UNIX_TIMESTAMP(modified),version from family_stable_id where family_id = ".$fam->dbID);
  $sth->execute();

  my @array = $sth->fetchrow_array();
  $fam->stable_id($array[0]);
  $fam->created($array[1]);
  $fam->modified($array[2]);
  $fam->version($array[3]);
  
  return $fam;
}

=head2 get_alignment_types

 Title	 : get_alignment_types
 Usage	 : $famAdptor->get_alignment_types($fam)
 Function: get the alignment types found for that family
 Returns :array of strings
 Args	 :


=cut

sub get_alignment_types{
  my ($self,$fam) = @_;
  my $sth = $self->prepare("select alignment_type from family_alignment where family_id=".$fam->dbID);
  $sth->execute();
  my @types;
  while (my $type = $sth->fetchrow_array()){
	push (@types, $type)
  }
 
  return @types;
}	 
  	

=head2 fetch_by_stable_id

 Title   : fetch_by_stable_id
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_stable_id{
  my ($self,$stable_id) = @_;
  
  my $query= "Select family_id from family_stable_id where stable_id = '$stable_id'";
  my $sth = $self->prepare($query);
  $sth->execute;

  my ($dbID) = $sth->fetchrow_array;

  if (!defined $dbID){
    $self->throw("Database does not contain family with stable id : $stable_id");
  }else{
    return $self->fetch_by_dbID($dbID);
  } 
}

=head2 get_members_of_db

 Title   : get_members_of_db
 Usage   : $famadp->get_members_of_db
 Function: get all members of the family which belong to a specified db 
 Returns : an array of Bio::EnsEMBL::Compara::Protein
 Args    : a family dbID, the database name

=cut

sub get_members_of_db{
	my ($self,$dbID,$dbname);
	if (!(defined $dbID) || !(defined $dbname)){
		$self->throw("Must supply a valid dbID and database name");
	}
   	my $sth = $self->prepare(" SELECT fp.protein_id,fp.rank 
							FROM family_protein fp,protein p,protein_db pdb 
							WHERE fp.family_id = $dbID 
							AND fp.protein_id = p.protein_id 
							AND p.protein_db_id=pdb.protein_db_id 
							AND pdb.name=$dbname");
   	$sth->execute;
   	my ($protein_id, $rank);
	my @proteins;
   	while (($protein_id,$rank) = $sth->fetchrow_array()){
   		my $protein = $self->db->get_ProteinAdaptor->fetch_by_dbID($protein_id);
	    $protein->family_rank($rank);
    	$protein->family_id($dbID);
		push @proteins, $protein;
   	}
	return @proteins;
}

=head2 store

 Title   : store
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub store{
   my ($self,$family) = @_;

   if( !defined $family) {
       $self->throw("Must provide a Bio::EnsEMBL::Compara::Family object");
   }
   ###store family### 

   my $sth = $self->prepare("INSERT INTO family(threshold,description,annotation_confidence_score) VALUES (?,?,?)");
   $sth->execute($family->threshold,$family->description,$family->annotation_score);
   my $dbID = $sth->{'mysql_insertid'};

   $family->dbID($dbID);
   $family->adaptor($self);
  
   ###store family members###
   my $rank = 0;

   my @members = sort {$b->family_score <=> $a->family_score} $family->get_all_members();

   foreach my $mem (@members){

	if (defined $mem->family_rank){
		$rank = $mem->family_rank;
	}
	else {
		$self->warn("rank not defined..giving one ");
		$rank++;
	}

    $self->db->get_ProteinAdaptor->store_if_needed($mem);#store into protein table if not already there
#	$self->throw("Protein rank not defined!") unless defined($mem->family_rank);
    $self->throw("Protein dbID not defined!") unless defined($mem->dbID);
   my $sth = $self->prepare("INSERT INTO family_protein(family_id,protein_id,rank,score) VALUES(?,?,?,?)");
    $sth->execute($dbID,$mem->dbID,$rank,$mem->family_score);#store into family_protein

   }
    ####store family stable_id###
    my $sth = $self->prepare("INSERT INTO family_stable_id(family_id, stable_id) VALUES (?,?)");
    
    if (defined $family->stable_id){
		$sth->execute($family->dbID, $family->stable_id);
    }
    else {
		my $stable_id;
		my $sth = $self->prepare("SELECT MAX(stable_id) from family_stable_id");
		$sth->execute;
		my $max= $sth->fetchrow_array;
		if (!$max){
				$stable_id = "ENSF00000000001";
		}
		else {
			$max++;
			$stable_id = $max; 
		}	
		$sth->execute($family->dbID,$stable_id);
    }
   
   return $family->dbID;
}

=head2 get_alignment_by_type

 Title	 : get_alignment_by_type
 Usage	 : $famAdptor->get_alignment_by_type
 Function: 
 Returns : a Bio::SimpleAlign obj
 Args	 : Bio::EnsEMBL::Compara::Family, string 

=cut

sub get_alignment_by_type{
	my ($self,$fam,$type)= @_;
	if (!$self->_type_exists($fam,$type)){
		$self->warn("alignment type $type for". $fam->dbID ." not found.");
		return undef;
	}
	$self->throw("[$fam] is not a Bio::EnsEMBL::Compara::Family obj!") unless $fam->isa("Bio::EnsEMBL::Compara::Family");
	
	###get the alignment string###
	my $dbID = $fam->dbID();
	my $q = "SELECT alignment
		FROM family_alignment 
		WHERE family_id = $dbID 
		AND alignment_type='$type'";

	$q = $self->prepare($q);
	$q->execute();

	###create the Bioperl AlignIO obj####
	my @align = $q->fetchrow_array();
	my $alignstr = $align[0];
	open(ALN,"echo \'$alignstr\' |");
	my $alnfh	= Bio::AlignIO->newFh('-format' => "$type",-fh => \*ALN);
 	my ($alignobj) = <$alnfh>;
	return $alignobj;

}

=head2 _type_exists

 Title	 : _type_exists 
 Usage	 : _type_exists($fam,$type); 
 Function:
 Returns : true if family contains that an alignment type, false otherwise 
 Args	 : Bio::EnsEMBL::Compara::Family, string 

=cut

sub _type_exists {
  my ($self,$fam,$type) = @_;
  $self->throw("[$fam] is not a Bio::EnsEMBL::Compara::Family obj!") unless $fam->isa("Bio::EnsEMBL::Compara::Family");
  my @types = $self->get_alignment_types($fam);
  foreach my $t(@types){
	if ($t =~/$type/){
		return 1;
	}
  }
  return 0;
}

=head2 get_all_alignments

 Title	 : get_all_alignments
 Usage	 : $famAdptor->get_all_alignments
 Function:
 Returns : a array Bio::SimpleAlign obj
 Args	 : Bio::EnsEMBL::Compara::Family

=cut

sub get_all_alignments{

	 my ($self,$fam)= @_;
	 $self->throw("[$fam] is not a Bio::EnsEMBL::Compara::Family obj!") unless $fam->isa("Bio::EnsEMBL::Compara::Family");
	 
	 ###get the alignment string###
	 my $dbID = $fam->dbID();
	 my $q = "SELECT alignment,alignment_type
	 	FROM family_alignment 
	 	WHERE family_id = $dbID"; 
                

	 $q = $self->prepare($q);
	 $q->execute();

	###create an array of SimpleAlign objects###
	 my @alignarray;
	 while (my @align = $q->fetchrow_array){
		my $alignstr = $align[0];
		my $aligntype = $align[1];
	 	open(ALN,"echo \'$alignstr\' |");
	 	my $alnfh     = Bio::AlignIO->newFh('-format' => "$aligntype",-fh => \*ALN);
	 	my ($alignobj) = <$alnfh>;
		push @alignarray, $alignobj;
	}
	 
	 return @alignarray;
}

=head2 store_alignment 

 Title	 : store_alignment 
 Usage	 : $famAdptor->store_alignment($fam,$aln,$type);
 Function: stores the alignment object into the database
 Returns :
 Args	 : Bio::EnsEMBL::Compara::Family, Bio::SimpleAlign, string

=cut

sub store_alignment{
	my ($self,$fam,$aln,$type) = @_;
	if ($type =~/clustalw/){ 
		#not sure of a better way of doing this than to writing to a tmp file
		#since SimpleAlign takes a file handle and prints the alignment in a clustalw
		#format
		open (ALN,">tmpfile");
		$aln->write_clustalw(\*ALN);
		close (ALN);
	
		open (ALN, "tmpfile");
		my @alnstr = <ALN>;
		close (ALN);
		my $alnstr = $self->_process_clustalw(@alnstr);# need to process clustalw output for storage into mysql
	        my $famid = $fam->dbID;	
		my $q = "INSERT INTO family_alignment(family_id,alignment_type,alignment)
			 VALUES ($famid ,'$type','$alnstr')";
		$q = $self->prepare($q);
		$q->execute();

		
	}
	else {
		$self->throw("Sorry storing alignment of type $type not functional yet!");
	}
}

=head2 _process_clustalw

 Title	 : _process_clustalw 
 Usage	 : _process_clustalw(@alnstr) 
 Function: process clustalw output for input into mysql db
 Returns : a string
 Args	 :

=cut	   	 

sub _process_clustalw {
     	my ($self,@alnstr) = @_;
	my $empty_lines = 0;
	my $alignment;
 	foreach my $line (@alnstr){
        	$line =~ s/\n/\\n/;
        	$alignment.=$line;
	}
	return $alignment;
}

=head2 get_Tree

 Title	 : get_Tree
 Usage	 : $famAdptor->get_Tree($fam);
 Function:
 Returns :
 Args	 :Bio::Tree::Tree

sub get_Tree {
	my ($self, $fam) = @_;
}

sub create_tree{
	my ($self, $fam) = @_;
=cut
	

1;
