=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor

=head1 SYNOPSIS

  use Bio::EnsEMBL::Registry;
  my $reg = "Bio::EnsEMBL::Registry";
  $reg->load_registry_from_db(-host=>"ensembldb.ensembl.org", -user=>"anonymous");

  my $genome_db_adaptor = $reg->get_adaptor("Multi", "compara", "GenomeDB");

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
use warnings;

use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseReleaseHistoryAdaptor');



#############################################################
# Implements Bio::EnsEMBL::Compara::RunnableDB::ObjectStore #
#############################################################

sub object_class {
    return 'Bio::EnsEMBL::Compara::GenomeDB';
}


###################
# fetch_* methods #
###################

=head2 fetch_by_name_assembly

  Arg [1]    : string $name
  Arg [2]    : string $assembly (optional)
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
    my $found_gdb = $assembly ?
        $self->_id_cache->get_by_additional_lookup('name_assembly', sprintf('%s_____%s', lc $name, lc $assembly))
        : $self->_id_cache->get_by_additional_lookup('name_default_assembly', lc $name);
    
    return $found_gdb;
}


=head2 fetch_all_by_taxon_id_assembly

  Arg[1]      : number (taxon_id)
  Arg[2]      : (Optional) string (assembly)
  Example     : $gdbs = $gdba->fetch_all_by_taxon_id_assembly(9606);
  Description : Retrieves GenomeDBs from the database based on taxon_id and (optionally) the assembly name
                If the assembly name is missing returns the GenomeDBs with the default assemblies.
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::GenomeDB's
  Exceptions  : none
  Caller      : general
  Status      : Experimental

=cut

sub fetch_all_by_taxon_id_assembly {  ## UNUSED
    my ($self, $taxon_id, $assembly) = @_;

    throw("taxon_id argument is required") unless ($taxon_id);

    my $found_gdbs = $assembly ?
        $self->_id_cache->get_all_by_additional_lookup('taxon_id_assembly', sprintf('%s____%s_', $taxon_id, lc $assembly))
            : $self->_id_cache->get_all_by_additional_lookup('taxon_id_default_assembly', $taxon_id);

    return $found_gdbs;
}

=head2 fetch_by_taxon_id

  Arg [1]    : number (taxon_id)
  Example    : $gdb = $gdba->fetch_by_taxon_id(1234);
  Description: Retrieves a genome db using the NCBI taxon_id of the species.
               If more than one GenomeDB is found in the database with the same
               taxon_id, gives the first one found.
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : thrown if $taxon_id is not given, or if there are more than 1
               GenomeDB with this taxon_id.
  Caller     : general
  Status     : Stable

=cut

sub fetch_by_taxon_id {
    my ($self, $taxon_id) = @_;

    throw("taxon_id argument is required") unless($taxon_id);

    my $found_gdbs = $self->_id_cache->get_all_by_additional_lookup('taxon_id', $taxon_id);
    throw("There are ".scalar(@$found_gdbs)." GenomeDBs with taxon_id = $taxon_id. GenomeDBAdaptor::fetch_by_taxon_id() doesn't know how to return only one.\n") if scalar(@$found_gdbs) >= 2;

    return $found_gdbs->[0];
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

  assert_ref($slice, 'Bio::EnsEMBL::Slice');
  unless ($slice->adaptor) {
    throw("[$slice] must have an adaptor");
  }

  my $core_dba = $slice->adaptor()->db();
  my $gdb = $self->fetch_by_core_DBAdaptor($core_dba);

  # 2015-03-18: the code below is greedy: it tries to find the component
  # genome_db that matches the slice instead of returning the principal
  # genome_db. It seems that we currently don't need to return component
  # genome_dbs here, so let's just skip this part for now.
  return $gdb;

  # We need to return the right genome_db if the slice is from a polyploid
  # genome. There are several ways of checking that:
  #  - meta key in the core database
  #  - slice attribute
  #  - component genome_dbs in the compara database
  # I have chosen the latter solution because the information is already in
  # memory and it saves us from doing another trip to the database
  if ($gdb->is_polyploid) {
    # That said, we now have to query the database if it is a polyploid genome
    my $all_comp_attr = $slice->get_all_Attributes('genome_component');
    throw("No 'genome_component' attribute found\n") unless scalar(@$all_comp_attr);
    throw("Too many 'genome_component' attributes !\n") if scalar(@$all_comp_attr) > 1;
    my $comp_name = $all_comp_attr->[0]->value;
    my $comp_gdb = $gdb->component_genome_dbs($comp_name) || throw("No genome_db for the component '$comp_name'\n");
    return $comp_gdb;
  } else {
    return $gdb;
  }
}


=head2 fetch_all_by_ancestral_taxon_id

  Arg [1]    : int $ancestral_taxon_id
  Example    : $gdb = $gdba->fetch_all_by_ancestral_taxon_id(1234);
  Description: Retrieves all the genome dbs derived from that NCBI taxon_id.
  Note       : This method uses the ncbi_taxa_node table
  Returntype : listref of Bio::EnsEMBL::Compara::GenomeDB obejcts
  Exceptions : 
  Caller     : general
  Status     : Stable

=cut

sub fetch_all_by_ancestral_taxon_id {
  my ($self, $taxon_id) = @_;

  unless($taxon_id) {
    throw('taxon_id argument is required');
  }

  my $sql = "SELECT genome_db_id FROM ncbi_taxa_node ntn1, ncbi_taxa_node ntn2, genome_db gdb
    WHERE ntn1.taxon_id = ? AND ntn1.left_index <= ntn2.left_index AND ntn1.right_index >= ntn2.left_index
    AND ntn2.taxon_id = gdb.taxon_id";

  return $self->_id_cache->get_by_sql($sql, [$taxon_id]);
}


=head2 fetch_all_by_low_coverage

  Example    : $low_cov_gdbs = $gdba->fetch_all_by_low_coverage();
  Description: Retrieves all the genome dbs that have low coverage
  Returntype : listref of Bio::EnsEMBL::Compara::GenomeDB obejcts
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_low_coverage {  ## UNUSED
    my ($self) = @_;
    return $self->_id_cache->get_all_by_additional_lookup('is_high_coverage', 0);
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
    my $species_assembly = $core_dba->assembly_name();
    return $self->fetch_by_name_assembly($species_name, $species_assembly);
}



=head2 fetch_all_polyploid

  Example     : $polyploid_gdbs = $genome_db_adaptor->fetch_all_polyploid();
  Description : Returns all the GenomeDBs of polyploid genomes
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::GenomeDB
  Exceptions  : none
  Caller      : general

=cut

sub fetch_all_polyploid {   ## UNUSED
    my $self = shift;
    return $self->_id_cache->get_all_by_additional_lookup('is_polyploid', 0);
}


##################
# store* methods #
##################

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

    assert_ref($gdb, 'Bio::EnsEMBL::Compara::GenomeDB');

    if(my $reference_dba = $self->db->reference_dba()) {
        $reference_dba->get_GenomeDBAdaptor->store( $gdb );
    }

    if($self->_synchronise($gdb)) {
        return $self->update($gdb);
    } else {
        my $sql = 'INSERT INTO genome_db (genome_db_id, name, assembly, genebuild, has_karyotype, is_high_coverage, taxon_id, genome_component, locator, first_release, last_release) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
        my $sth= $self->prepare( $sql ) or die "Could not prepare '$sql'\n";
        my $return_code = $sth->execute( $gdb->dbID, $gdb->name, $gdb->assembly, $gdb->genebuild, $gdb->has_karyotype, $gdb->is_high_coverage, $gdb->taxon_id, $gdb->genome_component, $gdb->locator, $gdb->first_release, $gdb->last_release )
            or die "Could not store gdb(name='".$gdb->name."', assembly='".$gdb->assembly."', genebuild='".$gdb->genebuild."')\n";

        $self->attach($gdb, $self->dbc->db_handle->last_insert_id(undef, undef, 'genome_db', 'genome_db_id') );
        $sth->finish();
    }

    #make sure the id_cache has been fully populated
    $self->_id_cache->put($gdb->dbID, $gdb);

    return $gdb;
}


=head2 update

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $gdb
  Example    : $gdba->update($gdb);
  Description: Updates the GenomeDB object in the database
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : thrown if the argument is not a Bio::EnsEMBL::Compara:GenomeDB
  Caller     : general
  Status     : Stable

=cut

sub update {
    my ($self, $gdb) = @_;

    assert_ref($gdb, 'Bio::EnsEMBL::Compara::GenomeDB');

    if(my $reference_dba = $self->db->reference_dba()) {
        $reference_dba->get_GenomeDBAdaptor->update( $gdb );
    }

    my $sql = 'UPDATE genome_db SET name=?, assembly=?, genebuild=?, taxon_id=?, genome_component=?, locator=?, first_release=?, last_release=? WHERE genome_db_id=?';
    my $sth = $self->prepare( $sql ) or die "Could not prepare '$sql'\n";
    $sth->execute( $gdb->name, $gdb->assembly, $gdb->genebuild, $gdb->taxon_id, $gdb->genome_component, $gdb->locator, $gdb->first_release, $gdb->last_release, $gdb->dbID );

    $self->attach($gdb, $gdb->dbID() );     # make sure it is (re)attached to the "$self" adaptor in case it got stuck to the $reference_dba
    $self->_id_cache->put($gdb->dbID, $gdb);

    return $gdb;
}


sub _find_missing_DBAdaptors {
    my $self = shift;

    # To avoid connecting to a database that is already linked to a GenomeDB
    my %already_known_dbas = ();
    foreach my $genome_db (@{$self->fetch_all}) {
        $already_known_dbas{$genome_db->{_db_adaptor}} = 1 if $genome_db->{_db_adaptor};
    }

    foreach my $db_adaptor (@{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'core')}) {

        next if $already_known_dbas{$db_adaptor};

        # Get the production name and assembly to compare to our GenomeDBs
        my $mc = $db_adaptor->get_MetaContainer();
        my $that_species = $mc->get_production_name();
        my $that_assembly = $db_adaptor->assembly_name();
        $db_adaptor->dbc->disconnect_if_idle();

        next unless $that_species;

        my $that_gdb = $self->fetch_by_name_assembly($that_species, $that_assembly);
        $that_gdb->db_adaptor($db_adaptor) if $that_gdb and not $that_gdb->{_db_adaptor};
    }

    my @missing = ();
    foreach my $genome_db (@{$self->fetch_all}) {
        next if $genome_db->{_db_adaptor};
        $genome_db->{_db_adaptor} = undef;
        push @missing, $genome_db;
    }
    warn("Cannot find all the core databases in the Registry. Be aware that getting Core objects from Compara is not possible for the following species/assembly: ".
        join(", ", map {sprintf('%s/%s', $_->name, $_->assembly)} @missing)."\n");
}

########################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor #
########################################################

sub _tables {
    return (['genome_db', 'g'])
}

sub _columns {
    return qw(
        g.genome_db_id
        g.name
        g.assembly
        g.taxon_id
        g.genebuild
        g.has_karyotype
        g.is_high_coverage
        g.genome_component
        g.locator
        g.first_release
        g.last_release
    )
}


sub _unique_attributes {
    return qw(
        name
        assembly
        genome_component
    )
}


sub _objs_from_sth {
    my ($self, $sth) = @_;
    my @genome_db_list = ();

    my ($dbid, $name, $assembly, $taxon_id, $genebuild, $has_karyotype, $is_high_coverage, $genome_component, $locator, $first_release, $last_release);
    $sth->bind_columns(\$dbid, \$name, \$assembly, \$taxon_id, \$genebuild, \$has_karyotype, \$is_high_coverage, \$genome_component, \$locator, \$first_release, \$last_release);
    while ($sth->fetch()) {

        my $gdb = Bio::EnsEMBL::Compara::GenomeDB->new_fast( {
            'adaptor'   => $self,           # field name in sync with Bio::EnsEMBL::Storable
            'dbID'      => $dbid,           # field name in sync with Bio::EnsEMBL::Storable
            'name'      => $name,
            'assembly'  => $assembly,
            'genebuild' => $genebuild,
            'has_karyotype' => $has_karyotype,
            'is_high_coverage' => $is_high_coverage,
            'taxon_id'  => $taxon_id,
            '_genome_component'  => $genome_component,
            'locator'   => $locator,
            '_first_release' => $first_release,
            '_last_release' => $last_release,
        } );

        $gdb->sync_with_registry();

        push @genome_db_list, $gdb;
    }

    # Here, we need to connect the genome_dbs for polyploid genomes
    my %gdb_per_key = map {$_->_get_unique_key => $_} (grep {not $_->genome_component} @genome_db_list);
    foreach my $gdb (@genome_db_list) {
        next unless $gdb->genome_component;
        my $key = $gdb->_get_unique_key;
        $gdb_per_key{$key}->component_genome_dbs($gdb->genome_component, $gdb) if $gdb_per_key{$key};
    }

    return \@genome_db_list;
}

############################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseFullAdaptor #
############################################################


sub _build_id_cache {
    my $self = shift;
    return Bio::EnsEMBL::Compara::DBSQL::Cache::GenomeDB->new($self);
}


package Bio::EnsEMBL::Compara::DBSQL::Cache::GenomeDB;

use base qw/Bio::EnsEMBL::Compara::DBSQL::Cache::WithReleaseHistory/;
use strict;
use warnings;

sub compute_keys {
    my ($self, $genome_db) = @_;
    return {
            ($genome_db->genome_component ? 'genome_component' : 'name_assembly') => $genome_db->_get_unique_key,

            # The extant species
            $genome_db->taxon_id ? (
                taxon_id => $genome_db->taxon_id,
                taxon_id_assembly => sprintf('%s____%s_', $genome_db->taxon_id, lc $genome_db->assembly),   ## UNUSED
            ) : (),

            # The species that are current and have a taxon_id (i.e. all but "ancestral_sequences")
            ($genome_db->taxon_id and $genome_db->is_current) ? (
                taxon_id_default_assembly => $genome_db->taxon_id,  ## UNUSED
                is_high_coverage => $genome_db->is_high_coverage,   ## UNUSED
                is_polyploid => $genome_db->is_polyploid,           ## UNUSED
            ) : (),

            # All the species that are current
            $genome_db->is_current ? (
                name_default_assembly => lc $genome_db->name    ## UNUSED
            ) : (),

            %{$self->SUPER::compute_keys($genome_db)},
           }
}


1;

