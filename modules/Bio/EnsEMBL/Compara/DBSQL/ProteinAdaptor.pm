#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::ProteinAdaptor
#
# Cared for by EnsEMBL <www.ensembl.org>
#
# Copyright GRL 
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::ProteinAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR  

This modules is part of the Ensembl project http://www.ensembl.org

Email ensembl-dev@ebi.ac.uk

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

   my $sth = $self->prepare("select protein_external_id, protein_external_dbname,peptide_sequence_id,seq_start, seq_end, strand,dnafrag_id from protein where protein_id = $dbid");
   $sth->execute;

   my ($external_id,$external_dbname,$peptide_sequence_id,$seq_start,$seq_end,$strand,$dnafrag_id) = $sth->fetchrow_array();

   if( !defined $external_id) {
       $self->throw("No protein with this dbID $dbid");
   }


   my $protein = Bio::EnsEMBL::Compara::Protein->new( 	-dbid 	=> $dbid,
														-external_id	=> $external_id,
														-external_dbname=> $external_dbname,
														-peptide_sequence_id=> $peptide_sequence_id,
														-seq_start	=> $seq_start,
														-seq_end	=> $seq_end,
														-strand	=> $strand,
														-dnafrag_id	=> $dnafrag_id);

   my $query = "Select sequence from peptide_sequence where peptide_sequence_id = ?";
   $sth = $self->prepare($query);
   $sth->execute($peptide_sequence_id);

   my ($seq) = $sth->fetchrow_array;

   $protein->seq($seq);
   $protein->moltype('protein');
   $protein->display_id($external_id);
   $protein->primary_id($external_id);
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

  $self->throw("Trying to fetch protein by external id without supplying an arg") unless defined $external_id;
  
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

=head2 fetch_Proteins_by_family_id

 Title   : fetch_Proteins_by_family_id
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_Proteins_by_family_id{

   my ($self,$family_id) = @_;

   $self->throw("Trying to fetch proteins in family without supplying a family dbID") unless defined $family_id;
 
   my $query= "Select protein_id from family_protein where family_id = $family_id";
   my $sth = $self->prepare($query);
   $sth->execute;

   my @proteins; 
   my $protein_dbID;


   while ($protein_dbID = $sth->fetchrow_array){
      my $prot = $self->fetch_by_dbID($protein_dbID); 
      push (@proteins,$prot);
   }

 
   $self->throw("Family with dbID = $family_id does not exists") unless defined @proteins;
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
   my ($self,$protein) = @_;

   if( !$protein->isa ('Bio::EnsEMBL::Compara::Protein')) {
       $self->throw("$protein must be a 'Bio::EnsEMBL::Compara::Protein'");
   }

   if( !defined $protein->external_id) {
       $self->throw("Protein must have a external id");
   }

   if (!defined $protein->seq){
       $self->warn("Storing compara protein with out a sequence attached to it.");
   }


   my $sth = $self->prepare("insert into peptide_sequence (sequence) values (?)");
   $sth->execute($protein->seq);

   $protein->peptide_sequence_id($sth->{'mysql_insertid'});

   my $sth = $self->prepare("insert into protein (protein_external_id,protein_external_dbname,peptide_sequence_id,seq_start,seq_end,strand,dnafrag_id) values (?,?,?,?,?,?,?)");


   # Should we flag if the protein has no dnafrag attached?

   $sth->execute($protein->external_id,$protein->external_dbname,$protein->peptide_sequence_id,$protein->seq_start,$protein->seq_end,$protein->strand,$dnafrag_id);

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

   if( !$protein->isa ('Bio::EnsEMBL::Compara::Protein')) {
       $self->throw("$protein must be a 'Bio::EnsEMBL::Compara::Protein'");
   }

   if( !defined $protein->external_id) {
       $self->throw("Protein must have a external id");
   }

   my $sth = $self->prepare("select protein_id from protein where protein_external_id = '".$protein->external_id."'");

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

=head2 fetch_peptide_seq

 Title   : fetch_peptide_seq
 Usage   : $self->fetch_peptide_seq($protein->dbID)
 Function: fetches the seq of a protein with a given dbID
 Example :
 Returns : peptide sequence as a string
 Args    : int dbID


=cut

sub fetch_peptide_seq {

  my ($self,$value);

  $self->throw("Trying to fetch peptide seq without giving a peptide sequence dbID");

  my $query = "Select sequence from peptide_sequence where peptide_sequence_id=? ";
  my $sth = $self->prepare($query);
  $sth->execute($value); 

  my ($str) = $sth->fetchrow_array 
        or $self->throw("No sequence stored for peptide sequence id $value");

  return $str;

}

1;
