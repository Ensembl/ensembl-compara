
#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor - DESCRIPTION of Object

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


package Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor;
use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::RootI

use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;

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

   my $sth = $self->prepare("select name,genome_db_id,dnafrag_type from dnafrag where dnafrag_id = $dbid");
   $sth->execute;

   my ($name,$genome_db_id,$type) = $sth->fetchrow_array();

   if( !defined $name) {
       $self->throw("No dnafrag with this dbID $dbid");
   }

   my $dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new();

   $dnafrag->dbID($dbid);
   $dnafrag->name($name);
   $dnafrag->type($type);
   $dnafrag->genomedb($self->db->get_GenomeDBAdaptor()->fetch_by_dbID($genome_db_id));

   return $dnafrag;

}

=head2 fetch_by_name_genomedb_id

 Title   : fetch_by_name_genome_db_id
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_name_genomedb_id{
   my ($self,$name,$genomedb_id) = @_;
 
   if( !defined $name) {
       $self->throw("fetch_by_name_genomedb_id requires dnafrag name");
   }
 
   if( !defined $genomedb_id) {
       $self->throw("fetch_by_name_genomedb_id requires genomedb_id");
   }

   my $sth = $self->prepare("select dnafrag_id,dnafrag_type from dnafrag where name = ? and genome_db_id = ?");
   $sth->execute($name,$genomedb_id);
 
   my ($dbID,$type) = $sth->fetchrow_array();
 
   if( !defined $dbID) {
       $self->throw("No dnafrag with this name $name and genomedb $genomedb_id");
   }
 
   my $dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new();
 
   $dnafrag->dbID($dbID);
   $dnafrag->name($name);
   $dnafrag->type($type);
   $dnafrag->genomedb($self->db->get_GenomeDBAdaptor()->fetch_by_dbID($genomedb_id));
 
   return $dnafrag;
}

=head2 fetch_all

 Title   : fetch_all
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_all{
   my ($self) = @_;
 
   my $query = "SELECT dnafrag_id FROM dnafrag";
   my $sth = $self->prepare($query);
   $sth->execute;

   my @dnafrags;

   while (my ($id) = $sth->fetchrow_array){
      my $dnafrag = $self->fetch_by_dbID($id);
      push (@dnafrags,$dnafrag);   
   }

   return @dnafrags;

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
   my ($self,$dnafrag) = @_;

   if( !defined $dnafrag ) {
       $self->throw("Must store $dnafrag object");
   }

   my $gdb = $dnafrag->genomedb();

   if( !defined $gdb || !ref $gdb || !$gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
       $self->throw("Must have genomedb attached to the dnafrag to store the dnafrag [$gdb]");
   }

   if( !defined $dnafrag || !ref $dnafrag || !$dnafrag->isa('Bio::EnsEMBL::Compara::DnaFrag') ) {
       $self->throw("Must have dnafrag arg [$dnafrag]");
   }

   if( !defined $gdb->dbID ) {
       $self->throw("genomedb must be stored (no dbID). Store genomedb first");
   }

   if( !defined $dnafrag->name ) {
       $self->throw("dna frag must have a name");
   }

   my $name = $dnafrag->name;
   my $gid =  $gdb->dbID;
   my $type = 'NULL';
   $type = $dnafrag->type if (defined $dnafrag->type);

   my $sth = $self->prepare("insert into dnafrag (name,genome_db_id,dnafrag_type) values (?,?,?)");

   $sth->execute($dnafrag->name,$gdb->dbID,$dnafrag->type);

   $dnafrag->dbID($sth->{'mysql_insertid'});
   $dnafrag->adaptor($self);

   return $dnafrag->dbID;
}

=head2 store_if_needed

 Title   : store_if_needed
 Usage   : $self->store_if_needed($dnafrag)
 Function: store instance in the defined database if NOT
           already present.
 Example :
 Returns : $dnafrag->dbID
 Args    : Bio::EnsEMBL::Compara::DnaFrag object


=cut

sub store_if_needed {
   my ($self,$dnafrag) = @_;

   if( !defined $dnafrag ) {
       $self->throw("Must store $dnafrag object");
   }

   my $gdb = $dnafrag->genomedb();

   if( !defined $gdb || !ref $gdb || !$gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
       $self->throw("Must have genomedb attached to the dnafrag to store the dnafrag [$gdb]");
   }

   if( !defined $dnafrag || !ref $dnafrag || !$dnafrag->isa('Bio::EnsEMBL::Compara::DnaFrag') ) {
       $self->throw("Must have dnafrag arg [$dnafrag]");
   }

   if( !defined $gdb->dbID ) {
       $self->throw("genomedb must be stored (no dbID). Store genomedb first");
   }

   if( !defined $dnafrag->name ) {
       $self->throw("dna frag must have a name");
   }
   
   my $name = $dnafrag->name;
   my $gid =  $gdb->dbID;
   my $sth = $self->prepare("select dnafrag_id from dnafrag where name='$name' and genome_db_id=$gid");

   unless ($sth->execute()) {
     $self->throw("Failed execution of a select query");
   }

   my ($dnafrag_id) = $sth->fetchrow_array();

   if (defined $dnafrag_id) {
     # $dnafrag already stored
     $dnafrag->dbID($dnafrag_id);
     return $dnafrag_id;
   } else {
     my $dnafrag_id = $self->store($dnafrag);
     return $dnafrag_id;
   }
}

1;
