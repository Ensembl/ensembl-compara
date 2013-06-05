=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

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

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor;

use strict;

use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor');


sub object_class {
    return 'Bio::EnsEMBL::Compara::GenomeDB';
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

    throw("name argument is required") unless($name);

    my $found_gdb;
    foreach my $gdb (@{ $self->fetch_all }) {
        if( (lc($gdb->name) eq lc($name)) and ($assembly ? (lc($gdb->assembly) eq lc($assembly)) : $gdb->assembly_default)) {
            if($found_gdb) {
                warning("Multiple matches found for name '$name' and assembly '".($assembly||'--undef--')."', returning the first one");
            } else {
                $found_gdb = $gdb;
            }
        }
    }
    
    throw("No matches found for name '$name' and assembly '".($assembly||'--undef--')."'") unless($found_gdb);

    return $found_gdb;
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

    throw("taxon_id argument is required") unless($taxon_id);
    my $found_gdb;
    foreach my $gdb (@{ $self->fetch_all }) {
        #Must test for $gdb->taxon_id since ancestral_sequences do not have a taxon_id
        if( ($gdb->taxon_id and  $gdb->taxon_id == $taxon_id) and $gdb->assembly_default ) {
            if($found_gdb) {
                warning("Multiple matches found for taxon_id '$taxon_id', returning the first one");
            } else {
                $found_gdb = $gdb;
            }
        }
    }
    
    throw("No matches found for taxon_id '$taxon_id'") unless($found_gdb);

    return $found_gdb;
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

  my $sql = "SELECT genome_db_id FROM ncbi_taxa_node ntn1, ncbi_taxa_node ntn2, genome_db gdb
    WHERE ntn1.taxon_id = ? AND ntn1.left_index < ntn2.left_index AND ntn1.right_index > ntn2.left_index
    AND ntn2.taxon_id = gdb.taxon_id";
  if ($default_assembly_only) {
    $sql .= " AND gdb.default_assembly = 1";
  }

  return $self->_fetch_cached_by_sql($sql, $taxon_id);
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
	my $species_name = $core_dba->get_MetaContainer->get_production_name();
	my ($highest_cs) = @{$core_dba->get_CoordSystemAdaptor->fetch_all()};
  my $species_assembly = $highest_cs->version();
  return $self->fetch_by_name_assembly($species_name, $species_assembly);
}



=head2 store

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $gdb
  Example    : $gdba->store($gdb);
  Description: Stores the GenomeDB object in the database unless it has been stored already; updates the dbID of the object.
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : thrown if the argument is not a Bio::EnsEMBL::Compara:GenomeDB
  Caller     : general
  Status     : Stable

=cut

sub store {
    my ($self, $gdb) = @_;

    if(my $reference_dba = $self->db->reference_dba()) {
        $reference_dba->get_GenomeDBAdaptor->store( $gdb );
    }

    if($self->_synchronise($gdb)) {
        my $sql = 'UPDATE genome_db SET taxon_id=?, assembly_default=?, locator=? WHERE genome_db_id=?';
        my $sth = $self->prepare( $sql ) or die "Could not prepare '$sql'";
        $sth->execute( $gdb->taxon_id, $gdb->assembly_default, $gdb->locator, $gdb->dbID );
        $sth->finish();
        $self->attach($gdb, $gdb->dbID() );     # make sure it is (re)attached to the "$self" adaptor in case it got stuck to the $reference_dba
    } else {
        my $sql = 'INSERT INTO genome_db (genome_db_id, name, assembly, genebuild, taxon_id, assembly_default, locator) VALUES (?, ?, ?, ?, ?, ?, ?)';
        my $sth= $self->prepare( $sql ) or die "Could not prepare '$sql'";
        my $return_code = $sth->execute( $gdb->dbID, $gdb->name, $gdb->assembly, $gdb->genebuild, $gdb->taxon_id, $gdb->assembly_default, $gdb->locator )
                # using $return_code in boolean context allows to skip the value '0E0' ('no rows affected') that Perl treats as zero but regards as true:
            or die "Could not store gdb(name='".$gdb->name."', assembly='".$gdb->assembly."', genebuild='".$gdb->genebuild."')";

        if($return_code > 0) {     # <--- for the same reason we have to be explicitly numeric here
            $self->attach($gdb, $self->dbc->db_handle->last_insert_id(undef, undef, 'genome_db', 'genome_db_id') );
            $sth->finish();
        }
    }

    $self->_add_to_cache($gdb);

    return $gdb;
}



sub _tables {

    return (['genome_db', 'g'])
}

sub _columns {
    return qw(
        g.genome_db_id
        g.name
        g.assembly
        g.taxon_id
        g.assembly_default
        g.genebuild
        g.locator
    )
}


sub _unique_attributes {
    return qw(
        name
        assembly
        genebuild
    )
}


sub _objs_from_sth {
    my ($self, $sth) = @_;
    my @genome_db_list = ();

    my ($dbid, $name, $assembly, $taxon_id, $assembly_default, $genebuild, $locator);
    $sth->bind_columns(\$dbid, \$name, \$assembly, \$taxon_id, \$assembly_default, \$genebuild, \$locator);
    while ($sth->fetch()) {

        my $gdb = Bio::EnsEMBL::Compara::GenomeDB->new_fast( {
            'adaptor'   => $self,           # field name in sync with Bio::EnsEMBL::Storable
            'dbID'      => $dbid,           # field name in sync with Bio::EnsEMBL::Storable
            'name'      => $name,
            'assembly'  => $assembly,
            'assembly_default' => $assembly_default,
            'genebuild' => $genebuild,
            'taxon_id'  => $taxon_id,
            'locator'   => $locator,
        } );
        $self->sync_with_registry($gdb);

        push @genome_db_list, $gdb;
    }
    return \@genome_db_list;
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

  my $genome_db = shift;
    next if $genome_db->locator and not $genome_db->locator =~ /^Bio::EnsEMBL::DBSQL::DBAdaptor/;
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


1;

