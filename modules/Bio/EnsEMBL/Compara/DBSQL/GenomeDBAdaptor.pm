

#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor - DESCRIPTION of Object

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


package Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor;
use vars qw(@ISA);
use strict;


use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;


# Hashes for storing a cross-referencing of compared genomes
my %genome_consensus_xreflist;
my %genome_query_xreflist;


@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

    
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

   # check to see whether all the GenomeDBs haev already been created
   if ( !defined $self->{'_GenomeDB_cache'}) {
     $self->create_GenomeDBs;
   }

   if ( defined $self->{'_cache'}->{$dbid}) {
     return $self->{'_cache'}->{$dbid};
   }
   else {  # return undef if fed a bogus dbID
     return undef;
   }
}


=head2 fetch_by_species_tag

 Title   : fetch_by_species_tag
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_species_tag{
   my ($self,$tag) = @_;

   my $sth = $self->prepare("
     SELECT genome_db_id 
     FROM genome_db 
     WHERE name = '$tag'
   ");
   $sth->execute;

   my ($id) = $sth->fetchrow_array();

   if( !defined $id ) {
       $self->throw("No species with this tag $tag");
   }

   return $self->fetch_by_dbID($id);

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
   my ($self,$gdb) = @_;

   if( !defined $gdb || !ref $gdb || !$gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
       $self->throw("Must have genomedb arg [$gdb]");
   }

   if( !defined $gdb->name || !defined $gdb->locator ) {
       $self->throw("genome db must have a name and a locator");
   }
   my $name = $gdb->name;
   my $locator = $gdb->locator;

   my $sth = $self->prepare("
      SELECT genome_db_id 
      FROM genome_db 
      WHERE name = '$name' and locator = '$locator'
   ");
   $sth->execute;

   my $dbID = $sth->fetchrow_array();

   if ($dbID) {
      $gdb->dbID($dbID);
   }else{ 
      my $sth = $self->prepare("
        INSERT into genome_db (name,locator) 
        VALUES ('$name','$locator')
      ");

      $sth->execute();

      $gdb->dbID($sth->{'mysql_insertid'});
   }

   return $gdb->dbID;
}


=head2 create_GenomeDBs
 
  Args       : none
  Example    : 
  Description: 
  Returntype : 
  Exceptions : none
  Caller     : 

=cut

sub create_GenomeDBs {
  my ( $self ) = @_;

  # Populate the hash array which cross-references the consensus
  # and query dbs

  my $sth = $self->prepare("
     SELECT consensus_genome_db_id, query_genome_db_id
     FROM genomic_align_genome
  ");

  $sth->execute;

  while ( my @db_row = $sth->fetchrow_array() ) {
    my ( $con, $query ) = @db_row;

    push @{ %genome_consensus_xreflist->{$con}}, $query;
    push @{ %genome_query_xreflist->{$query}}, $con;
  }
  
  # grab all the possible species databases in the genome db table
  $sth = $self->prepare("
     SELECT genome_db_id, name, locator 
     FROM genome_db 
   ");
   $sth->execute;
  
  # build a genome db for each species
  while ( my @db_row = $sth->fetchrow_array() ) {
    my ($dbid, $name, $locator) = @db_row;

    my $gdb = Bio::EnsEMBL::Compara::GenomeDB->new();
    $gdb->name($name);
    $gdb->locator($locator);
    $gdb->dbID($dbid);
    $self->{'_cache'}->{$dbid} = $gdb;
  }

  $self->{'_GenomeDB_cache'} = 1;  
}


=head2 check_for_consensus_db

  Arg[1]     : Bio::EnsEMBL::Compara::GenomeDB $consensus_genomedb
  Arg[2]     : Bio::EnsEMBL::Compara::GenomeDB $query_genomedb
  Example    : 
  Description: Checks to see whether a consensus genome database has been
               analysed against the specific query genome database.
               Returns the dbID of the database of the query genomeDB if 
               one is found.  A 0 is returned if no match is found.
  Returntype : int
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::GenomeDB.pm

=cut


sub check_for_consensus_db {
  my ( $self, $con_gdb, $query_gdb ) = @_;

  # just to make things a wee bit more readable
  my $cid = $con_gdb->dbID;
  my $qid = $query_gdb->dbID;
  
  if ( exists %genome_consensus_xreflist->{$cid} ) {
    for my $i ( 0 .. $#{%genome_consensus_xreflist->{$cid}} ) {
      if ( $qid == %genome_consensus_xreflist->{$cid}[$i] ) {
	return (%genome_consensus_xreflist->{$cid}[$i]);
      }
    }
  }
  return 0;
}



=head2 check_for_query_db

  Arg[1]     : Bio::EnsEMBL::Compara::GenomeDB $query_genomedb
  Arg[2]     : Bio::EnsEMBL::Compara::GenomeDB $consensus_genomedb
  Example    :  
  Description: Checks to see whether a query genome database has been
               analysed against the specific consensus genome database.
               Returns the dbID of the database of the consensus 
               genomeDB if one is found.  A 0 is returned if no match is
               found.
  Returntype : int
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::GenomeDB.pm

=cut

sub check_for_query_db {
  my ( $self, $query_gdb, $con_gdb ) = @_;

  # just to make things a wee bit more readable
  my $cid = $con_gdb->dbID;
  my $qid = $query_gdb->dbID;

  if ( exists %genome_query_xreflist->{$qid} ) {
    for my $i ( 0 .. $#{%genome_query_xreflist->{$qid}} ) {
      if ( $cid == %genome_query_xreflist->{$qid}[$i] ) {
	return (%genome_query_xreflist->{$qid}[$i]);
      }
    }
  }
  return 0;
}



=head2 get_db_links

  Arg        : Bio::EnsEMBL::Compara::GenomeDB $query_genomedb
  Example    : 
  Description: For the GenomeDB object passed in, check is run to
               verify which other genomes it has been analysed against
               irrespective as to whether this was as the consensus
               or query genome. Returns a list of matching dbIDs 
               separated by white spaces. 
  Returntype : string 
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::GenomeDB.pm

=cut

sub get_db_links {
  my ( $self, $ref_gdb ) = @_;
  
  my $id = $ref_gdb->dbID;
  my $db_list = "";

  # check for occurences of the db we are interested in
  # in the consensus list of dbs
  if ( exists %genome_consensus_xreflist->{$id} ) {
    $db_list = join (" ", @{%genome_consensus_xreflist->{$id}});
  }

  # and check for occurences of the db we are interested in
  # in the query list of dbs
  if ( exists %genome_query_xreflist->{$id} ) {
    $db_list .= " " . join (" ", @{%genome_query_xreflist->{$id}});
  }

  return $db_list;
}


1;
