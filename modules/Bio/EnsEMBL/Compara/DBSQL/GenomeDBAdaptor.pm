

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

  Arg [1]    : int $dbid
  Example    : $genome_db = $gdba->fetch_by_dbID(1);
  Description: Retrieves a GenomeDB object via its internal identifier
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : none
  Caller     : general

=cut

sub fetch_by_dbID{
   my ($self,$dbid) = @_;

   if( !defined $dbid) {
       $self->throw("Must fetch by dbid");
   }

   # check to see whether all the GenomeDBs have already been created
   if ( !defined $self->{'_GenomeDB_cache'}) {
     $self->create_GenomeDBs;
   }

   my $gdb = $self->{'_cache'}->{$dbid};

   if(!$gdb) {
     return undef; # return undef if fed a bogus dbID
   }

   #set up the dbadaptor for this genome db
   # this could have been added after the cache was created which is why
   # it is re-added every request
   my $dba = $self->db->get_db_adaptor($gdb->name, $gdb->assembly);
   if(!$dba) {
     $self->warn("Could not obtain DBAdaptor for dbID [$dbid].\n" .
		  "Genome DBAdaptor for name=[".$gdb->name."], ".
		  "assembly=[" . $gdb->assembly."] must be loaded using " .
		  "config file or\n" .
		  "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor::add_genome");
   }

   $gdb->db_adaptor($dba);

   return $gdb;
}


=head2 fetch_all

  Args       : none
  Example    : none
  Description: gets all GenomeDBs for this compara database
  Returntype : listref Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : none
  Caller     : general

=cut

sub fetch_all {
  my ( $self ) = @_;

  if ( !defined $self->{'_GenomeDB_cache'}) {
    $self->create_GenomeDBs;
  }

  my @genomeDBs = values %{$self->{'_cache'}};

  for my $gdb ( @genomeDBs ) {
    my $dba = $self->db->get_db_adaptor($gdb->name, $gdb->assembly);
    if($dba) {
      $gdb->db_adaptor($dba);
    }
  }
    
  return \@genomeDBs;
} 



=head2 fetch_by_name_assembly

  Arg [1]    : string $name
  Arg [2]    : string $assembly
  Example    : $gdb = $gdba->fetch_by_name_assembly("Homo sapiens", 'NCBI_31');
  Description: Retrieves a genome db using the name of the species and
               the assembly version.
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : thrown if GenomeDB of name $name and $assembly cannot be found
  Caller     : general

=cut

sub fetch_by_name_assembly{
   my ($self, $name, $assembly) = @_;

   unless($name) {
     $self->throw('name arguments are required');
   }
   
   my $sth;
   
   unless (defined $assembly) {
     my $sql = "SELECT genome_db_id FROM genome_db WHERE name = ? AND assembly_default = 1";
     $sth = $self->prepare($sql);
     $sth->execute($name);
   } else {
     my $sql = "SELECT genome_db_id FROM genome_db WHERE name = ? AND assembly = ?";
     $sth = $self->prepare($sql);
     $sth->execute($name, $assembly);
   }

   my ($id) = $sth->fetchrow_array();

   if( !defined $id ) {
       $self->throw("No GenomeDB with this name [$name] and " .
		    "assembly [$assembly]");
   }

   return $self->fetch_by_dbID($id);
}



=head2 store

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $gdb
  Example    : $gdba->store($gdb);
  Description: Stores a genome database object in the compara database if
               it has not been stored already.  The internal id of the
               stored genomeDB is returned.
  Returntype : int
  Exceptions : thrown if the argument is not a Bio::EnsEMBL::Compara:GenomeDB
  Caller     : general

=cut

sub store{
  my ($self,$gdb) = @_;

  unless(defined $gdb && ref $gdb && 
	 $gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
    $self->throw("Must have genomedb arg [$gdb]");
  }

  my $name = $gdb->name;
  my $assembly = $gdb->assembly;
  my $taxon_id = $gdb->taxon_id;

  unless($name && $assembly && $taxon_id) {
    $self->throw("genome db must have a name, assembly, and taxon_id");
  }

  my $assembly_default;
  unless (defined $gdb->assembly_default) {
    $assembly_default = 1;
    $gdb->assembly_default(1);
  } else {
    $assembly_default = $gdb->assembly_default;
  }
  
  my $sth = $self->prepare("
      SELECT genome_db_id
      FROM genome_db
      WHERE name = '$name' and assembly = '$assembly'
   ");

  $sth->execute;

  my $dbID = $sth->fetchrow_array();

  if(!$dbID) {
    #if the genome db has not been stored before, store it now
    my $sth = $self->prepare("
        INSERT into genome_db (name,assembly,taxon_id,assembly_default)
        VALUES ('$name','$assembly', $taxon_id, $assembly_default)
      ");

    $sth->execute();
    $dbID = $sth->{'mysql_insertid'};
  }

  #update the genomeDB object so that it's dbID and adaptor are set
  $gdb->dbID($dbID);
  $gdb->adaptor($self);

  return $dbID;
}



=head2 create_GenomeDBs

  Arg [1]    : none
  Example    : none
  Description: Reads the genomedb table and creates an internal cache of the
               values of the table.
  Returntype : none
  Exceptions : none
  Caller     : internal

=cut

sub create_GenomeDBs {
  my ( $self ) = @_;

  # Populate the hash array which cross-references the consensus
  # and query dbs

  my $sth = $self->prepare("
     SELECT consensus_genome_db_id, query_genome_db_id, method_link_id
     FROM genomic_align_genome
  ");

  $sth->execute;

  while ( my @db_row = $sth->fetchrow_array() ) {
    my ( $con, $query, $method_link_id ) = @db_row;

    $genome_consensus_xreflist{$con .":" .$method_link_id} ||= [];
    $genome_query_xreflist{$query .":" .$method_link_id} ||= [];

    push @{ $genome_consensus_xreflist{$con .":" .$method_link_id}}, $query;
    push @{ $genome_query_xreflist{$query .":" .$method_link_id}}, $con;
  }

  # grab all the possible species databases in the genome db table
  $sth = $self->prepare("
     SELECT genome_db_id, name, assembly, taxon_id, assembly_default
     FROM genome_db 
   ");
   $sth->execute;

  # build a genome db for each species
  while ( my @db_row = $sth->fetchrow_array() ) {
    my ($dbid, $name, $assembly, $taxon_id, $assembly_default) = @db_row;

    my $gdb = Bio::EnsEMBL::Compara::GenomeDB->new();
    $gdb->name($name);
    $gdb->assembly($assembly);
    $gdb->taxon_id($taxon_id);
    $gdb->assembly_default($assembly_default);
    $gdb->dbID($dbid);
    $gdb->adaptor( $self );

    $self->{'_cache'}->{$dbid} = $gdb;
  }

  $self->{'_GenomeDB_cache'} = 1;
}


=head2 check_for_consensus_db

  Arg[1]     : Bio::EnsEMBL::Compara::GenomeDB $consensus_genomedb
  Arg[2]     : Bio::EnsEMBL::Compara::GenomeDB $query_genomedb
  Arg[3]     : int $method_link_id
  Example    :
  Description: Checks to see whether a consensus genome database has been
               analysed against the specific query genome database.
               Returns the dbID of the database of the query genomeDB if 
               one is found.  A 0 is returned if no match is found.
  Returntype : int ( 0 or 1 )
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::GenomeDB.pm

=cut


sub check_for_consensus_db {
  my ( $self, $query_gdb, $con_gdb, $method_link_id) = @_;

  # just to make things a wee bit more readable
  my $cid = $con_gdb->dbID;
  my $qid = $query_gdb->dbID;
  
  if ( exists $genome_consensus_xreflist{$cid .":" .$method_link_id} ) {
    for my $i ( 0 .. $#{$genome_consensus_xreflist{$cid .":" .$method_link_id}} ) {
      if ( $qid == $genome_consensus_xreflist{$cid .":" .$method_link_id}[$i] ) {
	return 1;
      }
    }
  }
  return 0;
}


=head2 check_for_query_db

  Arg[1]     : Bio::EnsEMBL::Compara::GenomeDB $query_genomedb
  Arg[2]     : Bio::EnsEMBL::Compara::GenomeDB $consensus_genomedb
  Arg[3]     : int $method_link_id
  Example    : none
  Description: Checks to see whether a query genome database has been
               analysed against the specific consensus genome database.
               Returns the dbID of the database of the consensus 
               genomeDB if one is found.  A 0 is returned if no match is
               found.
  Returntype : int ( 0 or 1 )
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::GenomeDB.pm

=cut

sub check_for_query_db {
  my ( $self, $con_gdb, $query_gdb,$method_link_id ) = @_;

  # just to make things a wee bit more readable
  my $cid = $con_gdb->dbID;
  my $qid = $query_gdb->dbID;

  if ( exists $genome_query_xreflist{$qid .":" .$method_link_id} ) {
    for my $i ( 0 .. $#{$genome_query_xreflist{$qid .":" .$method_link_id}} ) {
      if ( $cid == $genome_query_xreflist{$qid .":" .$method_link_id}[$i] ) {
	return 1;
      }
    }
  }
  return 0;
}



=head2 get_all_db_links

  Arg[1]     : Bio::EnsEMBL::Compara::GenomeDB $query_genomedb
  Arg[2]     : int $method_link_id
  Example    : 
  Description: For the GenomeDB object passed in, check is run to
               verify which other genomes it has been analysed against
               irrespective as to whether this was as the consensus
               or query genome. Returns a list of matching dbIDs 
               separated by white spaces. 
  Returntype : listref of Bio::EnsEMBL::Compara::GenomeDBs 
  Exceptions : none
  Caller     : Bio::EnsEMBL::Compara::GenomeDB.pm

=cut

sub get_all_db_links {
  my ( $self, $ref_gdb,$method_link_id ) = @_;
  
  my $id = $ref_gdb->dbID;
  my @gdb_list;

  # check for occurences of the db we are interested in
  # in the consensus list of dbs
  if ( exists $genome_consensus_xreflist{$id . ":" .$method_link_id} ) {
    for my $i ( 0 .. $#{ $genome_consensus_xreflist{$id . ":" .$method_link_id} } ) {
      push @gdb_list, $self->{'_cache'}->{$genome_consensus_xreflist{$id . ":" .$method_link_id}[$i]};
    }
  }

  # and check for occurences of the db we are interested in
  # in the query list of dbs
  if ( exists $genome_query_xreflist{$id . ":" .$method_link_id} ) {
    for my $i ( 0 .. $#{ $genome_query_xreflist{$id . ":" .$method_link_id} } ) {
      push @gdb_list, $self->{'_cache'}->{$genome_query_xreflist{$id . ":" .$method_link_id}[$i]};
    }
  }

  return \@gdb_list;
}


1;

