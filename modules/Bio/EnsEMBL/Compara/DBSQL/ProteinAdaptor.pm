#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::ProteinAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::ProteinAdaptor - DESCRIPTION of Object

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


package Bio::EnsEMBL::Compara::DBSQL::ProteinAdaptor;
use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::RootI

use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::Protein;

@ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);


=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_dbID{
   my ($self,$dbid) = @_;

   if( !defined $dbid) {
       $self->throw("Must fetch by dbid");
   }

   my $sth = $self->prepare("select protein_external_id, protein_db_id ,seq_start, seq_end, strand,dnafrag_id from protein where protein_id = $dbid");
   $sth->execute;

   my ($external_id,$proteinDB_id,$seq_start,$seq_end,$strand,$dnafrag_id) = $sth->fetchrow_array();

   if( !defined $external_id) {
       $self->throw("No protein with this dbID $dbid");
   }

   my $dnafrag;

   eval{
     $dnafrag= $self->db->get_DnaFragAdaptor->fetch_by_dbID($dnafrag_id);
   }; if ($@) { $self->warn ("Unable to fetch dnafrag associated with this protein.");}

   my $proteinDB= $self->db->get_ProteinDBAdaptor->fetch_by_dbID($proteinDB_id);

   my $protein = Bio::EnsEMBL::Compara::Protein->new( 	-dbid 	=> $dbid,
														-external_id	=> $external_id,
														-proteinDB	=> $proteinDB,
														-seq_start	=> $seq_start,
														-seq_end	=> $seq_end,
														-strand	=> $strand,
														-dnafrag	=> $dnafrag);


   return $protein;

}

=head2 fetch_by_external_id

 Title   : fetch_by_external_id
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_external_id{
  my ($self,$external_id) = @_;
  
  my $query= "Select protein_id from protein where protein_external_id = '$external_id'";
  my $sth = $self->prepare($query);
  $sth->execute;

  my $dbID = $sth->fetchrow_array;

  if (!defined $dbID){
    $self->throw("Database does not contain protein with external_id: $external_id");
  }else{
    return $self->fetch_by_dbID($dbID);
  } 
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
   my ($self,$protein) = @_;

   if( !defined $protein) {
       $self->throw("Must store $protein object");
   }

   my $pdb = $protein->proteindb();
 
   if( !defined $pdb || !ref $pdb || !$pdb->isa('Bio::EnsEMBL::Compara::ProteinDB') ) {
       $self->throw("Must have proteindb attached to the protein to store the protein [$pdb]");
   }
 
   if( !defined $protein || !ref $protein || !$protein->isa('Bio::EnsEMBL::Compara::Protein') ) {
       $self->throw("Must have protein arg [$protein]");
   }
 
   if( !defined $pdb->dbID ) {
       $self->throw("proteindb must be stored (no dbID). Store proteindb first");
   }

   if( !defined $protein || !ref $protein || !$protein->isa('Bio::EnsEMBL::Compara::Protein') ) {
       $self->throw("Must have protein arg [$protein]");
   }

   if( !defined $protein->external_id) {
       $self->throw("Protein must have a external id");
   }


   my $sth = $self->prepare("insert into protein (protein_external_id,protein_db_id,seq_start,seq_end,strand,dnafrag_id)
                             values ('".$protein->external_id."',".
									  $protein->proteinDB->dbID."',".
                                      $protein->seq_start.",".
                                      $protein->seq_end.",".
                                      $protein->strand.",".
                                      $protein->dnafrag->dbID.")");

   $sth->execute();

   $protein->dbID($sth->{'mysql_insertid'});
   $protein->adaptor($self);

   return $protein->dbID;
}

=head2 store_if_needed

 Title   : store_if_needed
 Usage   : $self->store_if_needed($protein)
 Function: store instance in the defined database if NOT
           already present.
 Example :
 Returns : $protein->dbID
 Args    : Bio::EnsEMBL::Compara::Protein object


=cut

sub store_if_needed {
   my ($self,$protein) = @_;

   if( !defined $protein ) {
       $self->throw("Must store $protein object");
   }

   my $pdb = $protein->proteindb();

   if( !defined $pdb || !ref $pdb || !$pdb->isa('Bio::EnsEMBL::Compara::ProteinDB') ) {
       $self->throw("Must have proteindb attached to the protein to store the protein [$pdb]");
   }

   if( !defined $protein || !ref $protein || !$protein->isa('Bio::EnsEMBL::Compara::Protein') ) {
       $self->throw("Must have protein arg [$protein]");
   }
	
   if( !defined $pdb->dbID ) {
       $self->throw("proteindb must be stored (no dbID). Store proteindb first");
   }

   if( !defined $protein->external_id ) {
       $self->throw("protein must have a external_id");
   }
   
   my $sth = $self->prepare("select protein_id from protein where external_id = '".$protein->external_id."'");

   unless ($sth->execute()) {
     $self->throw("Failed execution of a select query");
   }

   my ($protein_id) = $sth->fetchrow_array();

   if (defined $protein_id) {
     # $protein already stored
     $protein->dbID($protein_id);
     return $protein_id;
   } else {
     my $protein_id = $self->store($protein);
     return $protein_id;
   }
}

1;
