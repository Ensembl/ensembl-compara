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

use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::DBSQL::BaseAdaptor');


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

=head2 fetch_all_by_ancestral_taxon_id

  Arg [1]    : int $ancestral_taxon_id
  Arg [2]    : (optional) bool $default_assembly_only
  Example    : $gdb = $gdba->fetch_by_taxon_id(1234);
  Description: Retrieves all the genome dbs derived from that NCBI taxon_id.
  Note       : This method uses the ncbi_taxa_node table
  Returntype : listref of Bio::EnsEMBL::Compara::GenomeDB obejcts
  Exceptions : 
  Caller     : general
  Status     : Stable

=cut

sub fetch_all_by_ancestral_taxon_id {
  my ($self, $taxon_id, $default_assembly_only) = @_;

  unless($taxon_id) {
    throw('taxon_id argument is required');
  }
  my $all_genome_dbs = $self->fetch_all; # loads the cache

  my $sth;

  my $sql = "SELECT genome_db_id FROM ncbi_taxa_node ntn1, ncbi_taxa_node ntn2, genome_db gdb
    WHERE ntn1.taxon_id = ? AND ntn1.left_index < ntn2.left_index AND ntn1.right_index > ntn2.left_index
    AND ntn2.taxon_id = gdb.taxon_id";
  if ($default_assembly_only) {
    $sql .= " AND gdb.default_assembly = 1";
  }

  $sth = $self->prepare($sql);
  $sth->execute($taxon_id);
  my $genome_db_id;
  $sth->bind_columns(\$genome_db_id);

  # Create a string of dbIDs separated by colons for quick search
  my $genome_db_id_string = ":";
  while ($sth->fetch) {
    $genome_db_id_string .= $genome_db_id.":";
  }
  $sth->finish;

  # Run the quick search
  my $these_genome_dbs = [grep {index($genome_db_id_string, ":".$_->dbID.":") > -1} @$all_genome_dbs];
  
  return $these_genome_dbs;
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
  my ($species_name) = @{$meta_container->list_value_by_key('species.production_name')};
  unless(defined $species_name) {
    $species_name = $meta_container->get_Species->binomial;
	}
  throw('Species name was still empty/undefined after looking for species.production_name and binomial name') unless $species_name;
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

sub store {
    my ($self, $gdb) = @_;

    unless(defined $gdb && ref $gdb && $gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
        throw("Must have genomedb arg [$gdb]");
    }

    my $dbID                = $gdb->dbID;
    my $name                = $gdb->name;
    my $assembly            = $gdb->assembly;
    my $genebuild           = $gdb->genebuild;

    my $taxon_id            = $gdb->taxon_id;
    my $assembly_default    = $gdb->assembly_default;
    my $locator             = $gdb->locator;

    if($taxon_id and not ($name && $assembly && $genebuild)) {
        throw("GenomeDB object with a non-zero taxon_id must have a name, assembly and genebuild");
    }

    my $dbid_check = $dbID ? "genome_db_id=$dbID" : '0';
    my @unique_key_data = ($name, $assembly, $genebuild);

    my $sth_select = $self->prepare("SELECT genome_db_id, (name=? AND assembly=? AND genebuild=?) FROM genome_db WHERE $dbid_check OR (name=? AND assembly=? AND genebuild=?)");
    $sth_select->execute( @unique_key_data, @unique_key_data );
    my $vectors = $sth_select->fetchall_arrayref();
    $sth_select->finish();

    if( scalar(@$vectors) == 0 ) { # none found, safe to insert

        my $sth_insert = $self->prepare("INSERT INTO genome_db (genome_db_id, name, assembly, genebuild, taxon_id, assembly_default, locator) VALUES (?, ?, ?, ?, ?, ?, ?)");
        $sth_insert->execute( $dbID, $name, $assembly, $genebuild, $taxon_id, $assembly_default, $locator );

        $dbID ||= $self->dbc->db_handle->last_insert_id(undef, undef, 'genome_db', 'genome_db_id');
        $sth_insert->finish();

    } elsif( scalar(@$vectors) >= 2 ) {

        die "Attempting to store a GenomeDB object with dbID=$dbID and name/assembly/genebuild=$name/$assembly/$genebuild experienced partial collisions both with dbID and UNIQUE KEY in the db";

    } else {
        my ($stored_dbID, $unique_key_check) = @{$vectors->[0]};

        if(!$unique_key_check) {

            die "Attempting to store a GenomeDB object with dbID=$dbID experienced a collision with same dbID but different data";

        } elsif($dbID and ($dbID != $stored_dbID)) {

            die "Attempting to store a GenomeDB object with name/assembly/genebuild=$name/$assembly/$genebuild experienced a collision with same UNIQUE KEY but different dbID";

        } else {

            $dbID ||= $stored_dbID;
            
            my $sth_update = $self->prepare("UPDATE genome_db SET taxon_id=?, assembly_default=?, locator=? WHERE genome_db_id=?");
            $sth_update->execute( $taxon_id, $assembly_default, $locator, $stored_dbID );
            $sth_update->finish();
        }
    }

    $gdb->dbID( $dbID );
    $gdb->adaptor( $self );

    return $gdb;
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

  # grab all the possible species databases in the genome db table
  my $sth = $self->prepare("
     SELECT genome_db_id, name, assembly, taxon_id, assembly_default, genebuild, locator
     FROM genome_db
   ");
   $sth->execute;

  # build a genome db for each species
  $self->{'_cache'} = undef;
  my ($dbid, $name, $assembly, $taxon_id, $assembly_default, $genebuild, $locator);
  $sth->bind_columns(\$dbid, \$name, \$assembly, \$taxon_id, \$assembly_default, \$genebuild, \$locator);
  while ($sth->fetch()) {

    my $gdb = Bio::EnsEMBL::Compara::GenomeDB->new_fast(
        {'name' => $name,
        'dbID' => $dbid,
        'adaptor' => $self,
        'assembly' => $assembly,
        'assembly_default' => $assembly_default,
        'genebuild' => $genebuild,
        'taxon_id' => $taxon_id,
        'locator' => $locator});

    $self->{'_cache'}->{$dbid} = $gdb;
  }

  $sth->finish();

  $self->{'_GenomeDB_cache'} = 1;

  $self->sync_with_registry();
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

