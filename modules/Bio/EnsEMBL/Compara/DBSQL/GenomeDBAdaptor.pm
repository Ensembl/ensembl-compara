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

  use Bio::EnsEMBL::Registry;

  my $reg = "Bio::EnsEMBL::Registry";

  $reg->load_registry_from_db(-host=>"ensembldb.ensembl.org", -user=>"anonymous");
  my $genome_db_adaptor = $reg->get_adaptor("Multi", "compara", "GenomeDB");

  $genome_db_adaptor->store($genome_db);

  $genome_db = $genome_db_adaptor->fetch_by_dbID(22);
  $all_genome_dbs = $genome_db_adaptor->fetch_all();
  $genome_db = $genome_db_adaptor->fetch_by_name_assembly("Homo sapiens", 'NCBI36');
  $genome_db = $genome_db_adaptor->fetch_by_registry_name("human");
  $genome_db = $genome_db_adaptor->fetch_by_Slice($slice);

=head1 DESCRIPTION

This module is intended to access data in the genome_db table. The genome_db table stores information about each species including the taxon_id, species name, assembly, genebuild and the location of the core database

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
use Bio::EnsEMBL::Utils::Exception;

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
  Status     : Stable

=cut

sub fetch_by_dbID {
   my ($self,$dbid) = @_;

   if( !defined $dbid) {
       throw("Must fetch by dbid");
   }

   # check to see whether all the GenomeDBs have already been created
   if ( !defined $self->{'_GenomeDB_cache'}) {
     $self->create_GenomeDBs;
   }

   my $gdb = $self->{'_cache'}->{$dbid};

   if(!$gdb) {
     return undef; # return undef if fed a bogus dbID
   }

   return $gdb;
}


=head2 fetch_all

  Args       : none
  Example    : my $all_genome_dbs = $genome_db_adaptor->fetch_all();
  Description: gets all GenomeDBs for this compara database
  Returntype : listref Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub fetch_all {
  my ( $self ) = @_;

  if ( !defined $self->{'_GenomeDB_cache'}) {
    $self->create_GenomeDBs;
  }

  my @genomeDBs = values %{$self->{'_cache'}};

  return \@genomeDBs;
}

=head2 fetch_by_name_assembly

  Arg [1]    : string $name
  Arg [2]    : string $assembly
  Example    : $gdb = $gdba->fetch_by_name_assembly("Homo sapiens", 'NCBI36');
  Description: Retrieves a genome db using the name of the species and
               the assembly version.
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : thrown if GenomeDB of name $name and $assembly cannot be found
  Caller     : general
  Status      : Stable

=cut

sub fetch_by_name_assembly {
  my ($self, $name, $assembly) = @_;

  unless($name) {
    throw('name arguments are required');
  }

  my $sth;

  unless (defined $assembly && $assembly ne '') {
    my $sql = "SELECT genome_db_id FROM genome_db WHERE name = ? AND assembly_default = 1";
    $sth = $self->prepare($sql);
    $sth->execute($name);
  } else {
    my $sql = "SELECT genome_db_id FROM genome_db WHERE name = ? AND assembly = ?";
    $sth = $self->prepare($sql);
    $sth->execute($name, $assembly);
  }

  my ($id) = $sth->fetchrow_array();

  if (!defined $id) {
    throw("No GenomeDB with this name [$name] and assembly [".
        ($assembly or "--undef--")."]");
  }
  $sth->finish;
  return $self->fetch_by_dbID($id);
}

=head2 fetch_by_registry_name

  Arg [1]    : string $name
  Example    : $gdb = $gdba->fetch_by_registry_name("human");
  Description: Retrieves a genome db using the name of the species as
               used in the registry configuration file. Any alias is
               acceptable as well.
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : thrown if $name is not found in the Registry configuration
  Caller     : general
  Status     : Stable

=cut

sub fetch_by_registry_name {
  my ($self, $name) = @_;

  unless($name) {
    throw('name arguments are required');
  }

  my $species_db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($name, "core");
  if (!$species_db_adaptor) {
    throw("Cannot connect to core database for $name!");
  }

  return $self->fetch_by_core_DBAdaptor($species_db_adaptor);
}

=head2 fetch_by_Slice

  Arg [1]    : Bio::EnsEMBL::Slice $slice
  Example    : $gdb = $gdba->fetch_by_Slice($slice);
  Description: Retrieves the genome db corresponding to this
               Bio::EnsEMBL::Slice object
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : thrown if $slice is not a Bio::EnsEMBL::Slice
  Caller     : general
  Status     : Stable

=cut

sub fetch_by_Slice {
  my ($self, $slice) = @_;

  unless (UNIVERSAL::isa($slice, "Bio::EnsEMBL::Slice")) {
    throw("[$slice] must be a Bio::EnsEMBL::Slice");
  }
  unless ($slice->adaptor) {
    throw("[$slice] must have an adaptor");
  }

  my $core_dba = $slice->adaptor()->db();
  return $self->fetch_by_core_DBAdaptor($core_dba);
}

=head2 fetch_by_taxon_id

  Arg [1]    : string $name
  Arg [2]    : string $assembly
  Example    : $gdb = $gdba->fetch_by_taxon_id(1234);
  Description: Retrieves a genome db using the NCBI taxon_id of the species.
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : thrown if GenomeDB of taxon_id $taxon_id cannot be found. Will
               warn if the taxon returns more than one GenomeDB (possible in
               some branches of the Taxonomy)
  Caller     : general
  Status     : Stable

=cut

sub fetch_by_taxon_id {
  my ($self, $taxon_id) = @_;

  unless($taxon_id) {
    throw('taxon_id argument is required');
  }

  my $sth;

  my $sql = "SELECT genome_db_id FROM genome_db WHERE taxon_id = ? AND assembly_default = 1";
  $sth = $self->prepare($sql);
  $sth->execute($taxon_id);

  my @ids = $sth->fetchrow_array();
  $sth->finish;

  my $return_count = scalar(@ids);
	my $id;
  if ($return_count ==0) {
    throw("No GenomeDB with this taxon_id [$taxon_id]");
  }
  else {
    ($id) = @ids;
    if($return_count > 1) {
      warning("taxon_id [${taxon_id}] returned more than one row. Returning the first at ID [${id}]");
    }
  }

  return $self->fetch_by_dbID($id);
}

=head2 fetch_by_core_DBAdaptor

	Arg [1]     : Bio::EnsEMBL::DBSQL::DBAdaptor
	Example     : my $gdb = $gdba->fetch_by_core_DBAdaptor($core_dba);
	Description : For a given core database adaptor object; this method will
	              return the GenomeDB instance
	Returntype  : Bio::EnsEMBL::Compara::GenomeDB
	Exceptions  : thrown if no name is found for the adaptor
	Caller      : general
	Status      : Stable

=cut

sub fetch_by_core_DBAdaptor {
	my ($self, $core_dba) = @_;
	my $mc = $core_dba->get_MetaContainer();
	my $species_name = $self->get_species_name_from_core_MetaContainer($mc);
	my ($highest_cs) = @{$core_dba->get_CoordSystemAdaptor->fetch_all()};
  my $species_assembly = $highest_cs->version();
  return $self->fetch_by_name_assembly($species_name, $species_assembly);
}

=head2 get_species_name_from_core_MetaContainer

  Arg [1]     : Bio::EnsEMBL::MetaContainer
  Example     : $gdba->get_species_name_from_core_MetaContainer($slice->adaptor->db->get_MetaContainer);
  Description : Returns the name of a species which was used to
                name the GenomeDB from a meta container. Can be
                the species binomial name or the value of the
                meta item species.compara_name
  Returntype  : Scalar string
  Exceptions  : thrown if no name is found
  Caller      : general
  Status      : Stable

=cut

sub get_species_name_from_core_MetaContainer {
	my ($self, $meta_container) = @_;
  my ($species_name) = @{$meta_container->list_value_by_key('species.compara_name')};
  unless(defined $species_name) {
    $species_name = $meta_container->get_Species->binomial;
	}
  throw('Species name was still empty/undefined after looking for species.compara_name and binomial name') unless $species_name;
  return $species_name;
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
  Status     : Stable

=cut

sub store{
  my ($self,$gdb) = @_;

  unless(defined $gdb && ref $gdb &&
	 $gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
    throw("Must have genomedb arg [$gdb]");
  }

  my $name = $gdb->name;
  my $assembly = $gdb->assembly;
  my $assembly_default = $gdb->assembly_default;
  my $taxon_id = $gdb->taxon_id;
  my $genebuild = $gdb->genebuild;
  my $locator = $gdb->locator;

  if ($taxon_id == 0 and !$assembly) {
     $assembly = "";
  } else {
      unless($name && $assembly && $taxon_id) {
	  throw("genome db must have a name, assembly, and taxon_id");
      }
  }

  my $sth = $self->prepare("
      SELECT genome_db_id
      FROM genome_db
      WHERE taxon_id='$taxon_id' AND name = '$name'
      AND assembly = '$assembly' AND genebuild = '$genebuild'
   ");

  $sth->execute;

  my ($dbID) = $sth->fetchrow_array();

  $sth->finish();

  if(!$dbID) {
    #if the genome db has not been stored before, store it now
   # my $sql = "INSERT into genome_db (name,assembly,taxon_id,assembly_default,genebuild,locator) ".
    #          " VALUES ('$name','$assembly', $taxon_id, $assembly_default, '$genebuild', '$locator')";

     my $sql = qq(
           INSERT into genome_db (name,assembly,taxon_id,assembly_default,genebuild,locator)
           VALUES (?,?,?,?,?,?)
        );

     #print("$sql\n");
     $sth = $self->prepare($sql);
     $sth->bind_param(1, $name, SQL_VARCHAR);
     $sth->bind_param(2, $assembly, SQL_VARCHAR);
     $sth->bind_param(3, $taxon_id, SQL_INTEGER);
     $sth->bind_param(4, $assembly_default, SQL_TINYINT);
     $sth->bind_param(5, $genebuild, SQL_VARCHAR);
     $sth->bind_param(6, $locator, SQL_VARCHAR);

    if($sth->execute()) {
      $dbID = $sth->{'mysql_insertid'};
      $sth->finish();

      if($gdb->dbID) {
        $sql = "UPDATE genome_db SET genome_db_id=".$gdb->dbID .
               " WHERE genome_db_id=$dbID";
        my $sth = $self->prepare($sql);
        if($sth->execute()) { $dbID = $gdb->dbID; }
        $sth->finish();
      }
    }
  }
  else {
    my $sql = "UPDATE genome_db SET ".
              " assembly_default = '$assembly_default'".
              " ,locator = '$locator'".
              " WHERE genome_db_id=$dbID";
    #print("$sql\n");
    $sth = $self->prepare($sql);
    $sth->execute();
    $sth->finish();
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
  Status      : Stable

=cut

sub create_GenomeDBs {
  my ( $self ) = @_;

  # Populate the hash array which cross-references the consensus
  # and query dbs

#   my $sth = $self->prepare("
#      SELECT consensus_genome_db_id, query_genome_db_id, method_link_id
#      FROM genomic_align_genome
#   ");
#
#   $sth->execute;
#
#   while ( my @db_row = $sth->fetchrow_array() ) {
#     my ( $con, $query, $method_link_id ) = @db_row;
#
#     $genome_consensus_xreflist{$con .":" .$method_link_id} ||= [];
#     $genome_query_xreflist{$query .":" .$method_link_id} ||= [];
#
#     push @{ $genome_consensus_xreflist{$con .":" .$method_link_id}}, $query;
#     push @{ $genome_query_xreflist{$query .":" .$method_link_id}}, $con;
#   }

  # grab all the possible species databases in the genome db table
  my $sth = $self->prepare("
     SELECT genome_db_id, name, assembly, taxon_id, assembly_default, genebuild, locator
     FROM genome_db
   ");
   $sth->execute;

  # build a genome db for each species
  $self->{'_cache'} = undef;
  while ( my @db_row = $sth->fetchrow_array() ) {
    my ($dbid, $name, $assembly, $taxon_id, $assembly_default, $genebuild, $locator) = @db_row;

    my $gdb = Bio::EnsEMBL::Compara::GenomeDB->new();
    $gdb->name($name);
    $gdb->assembly($assembly);
    $gdb->taxon_id($taxon_id);
    $gdb->assembly_default($assembly_default);
    $gdb->dbID($dbid);
    $gdb->adaptor( $self );
    $gdb->genebuild($genebuild);
    $gdb->locator($locator);

    $self->{'_cache'}->{$dbid} = $gdb;
  }

  $sth->finish();

  $self->{'_GenomeDB_cache'} = 1;

  $self->sync_with_registry();
}


=head2 check_for_consensus_db [DEPRECATED]

  DEPRECATED : consensus and query sequences are not used anymore.
               Please, refer to Bio::EnsEMBL::Compara::GenomicAlignBlock
               for more details.

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

  deprecate("consensus and query sequences are not used anymore.".
              " Please, refer to Bio::EnsEMBL::Compara::GenomicAlignBlock".
              " for more details");

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


=head2 check_for_query_db [DEPRECATED]

  DEPRECATED : consensus and query sequences are not used anymore.
               Please, refer to Bio::EnsEMBL::Compara::GenomicAlignBlock
               for more details.

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

  deprecate("consensus and query sequences are not used anymore.".
              " Please, refer to Bio::EnsEMBL::Compara::GenomicAlignBlock".
              " for more details");

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
  Status     : At risk

=cut

sub get_all_db_links {
  my ($self, $ref_gdb, $method_link_id) = @_;

  my $gdb_list;

  my $method_link_species_set_adaptor = $self->db->get_MethodLinkSpeciesSetAdaptor;
  my $method_link_type = $method_link_species_set_adaptor->
      get_method_link_type_from_method_link_id($method_link_id);
  my $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_type_GenomeDB(
          $method_link_type,
          $ref_gdb
      );

  foreach my $this_method_link_species_set (@{$method_link_species_sets}) {
    foreach my $this_genome_db (@{$this_method_link_species_set->species_set}) {
      next if ($this_genome_db->dbID eq $ref_gdb->dbID);
      $gdb_list->{$this_genome_db} = $this_genome_db;
    }
  }

  return [values %$gdb_list];
}


=head2 sync_with_registry

  Example    :
  Description: Synchronize all the cached genome_db objects
               db_adaptor (connections to core databases)
               with those set in Bio::EnsEMBL::Registry.
               Order of presidence is Registry.conf > ComparaConf > genome_db.locator
  Returntype : none
  Exceptions : none
  Caller     : Bio::EnsEMBL::DBSQL::DBAdaptor
  Status     : At risk

=cut

sub sync_with_registry {
  my $self = shift;

  return unless(eval "require Bio::EnsEMBL::Registry");

  #print("Registry eval TRUE\n");
  my $genomeDBs = $self->fetch_all();

  foreach my $genome_db (@{$genomeDBs}) {
    my $coreDBA;
    my $registry_name;
    if ($genome_db->assembly) {
      $registry_name = $genome_db->name ." ". $genome_db->assembly;
      if(Bio::EnsEMBL::Registry->alias_exists($registry_name)) {
        $coreDBA = Bio::EnsEMBL::Registry->get_DBAdaptor($registry_name, 'core');
      }
    }
    if(!defined($coreDBA) and Bio::EnsEMBL::Registry->alias_exists($genome_db->name)) {
      $coreDBA = Bio::EnsEMBL::Registry->get_DBAdaptor($genome_db->name, 'core');
      Bio::EnsEMBL::Registry->add_alias($genome_db->name, $registry_name) if ($registry_name);
    }

    if($coreDBA) {
      #defined in registry so override any previous connection
      #and set in GenomeDB object (ie either locator or compara.conf)
      $genome_db->db_adaptor($coreDBA);
    } else {
      #fetch from genome_db which may be from a compara.conf or from
      #a locator
      $coreDBA = $genome_db->db_adaptor();
      if(defined($coreDBA)) {
        if (Bio::EnsEMBL::Registry->alias_exists($genome_db->name)) {
          Bio::EnsEMBL::Registry->add_alias($genome_db->name, $registry_name) if ($registry_name);
        } else {
          Bio::EnsEMBL::Registry->add_DBAdaptor($registry_name, 'core', $coreDBA);
          Bio::EnsEMBL::Registry->add_alias($registry_name, $genome_db->name) if ($registry_name);
        }
      }
    }
  }
}

=head2 deleteObj

  Arg         : none
  Example     : none
  Description : Called automatically by DBConnection during object destruction
                phase. Clears the cache to avoid memory leaks.
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub deleteObj {
  my $self = shift;

  if($self->{'_cache'}) {
    foreach my $dbID (keys %{$self->{'_cache'}}) {
      delete $self->{'_cache'}->{$dbID};
    }
  }

  $self->SUPER::deleteObj;
}


1;

