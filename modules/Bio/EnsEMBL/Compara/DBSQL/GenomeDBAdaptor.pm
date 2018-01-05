=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

use List::Util qw(max);
use Scalar::Util qw(blessed looks_like_number);

use Bio::EnsEMBL::Compara::GenomeDB;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(:assert :array);

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
  Arg [3]    : string $component (optional)
  Example    : $gdb = $gdba->fetch_by_name_assembly("Homo sapiens", 'NCBI36');
  Description: Retrieves a genome db using the name of the species and
               the assembly version.
  Returntype : Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : thrown if $name is not defined
  Caller     : general
  Status     : Stable

=cut

sub fetch_by_name_assembly {
    my ($self, $name, $assembly, $component) = @_;

    throw("name argument is required") unless($name);

    if ($component) {
        die 'The component filter requires an assembly name' unless $assembly;
        my $gdbs = $self->_id_cache->get_all_by_additional_lookup('genome_component', sprintf('%s_____%s', lc $name, lc $assembly));
        my @these_gdbs = grep {$_->genome_component eq $component} @$gdbs;
        return $these_gdbs[0];

    } elsif ($assembly) {
        return $self->_id_cache->get_by_additional_lookup('name_assembly', sprintf('%s_____%s', lc $name, lc $assembly));
    }

    my $found_gdb = $self->_id_cache->get_by_additional_lookup('name_default_assembly', lc $name);
    return $found_gdb if $found_gdb;

    my $all_matching_names = $self->_id_cache->get_all_by_additional_lookup('name', lc $name);
    return undef unless scalar(@$all_matching_names);

    # Otherwise, we need to find the best match
    my $best = $self->_find_most_recent($all_matching_names);
    push @{$self->_id_cache->_additional_lookup()->{name_default_assembly}->{lc $name}}, $best->dbID;   # Cached for the next call
    return $best;
}


=head2 fetch_all_by_name

  Arg [1]    : string $name
  Example    : $gdb = $gdba->fetch_all_by_name_assembly('homo_sapiens');
  Description: Retrieves all the genome db using the name of the species
  Returntype : Arrayref of Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : thrown if $name is not defined
  Caller     : general
  Status     : Stable

=cut

sub fetch_all_by_name {
    my ($self, $name) = @_;

    throw("name argument is required") unless($name);

    return $self->_id_cache->get_all_by_additional_lookup('name', lc $name);
}


=head2 fetch_all_by_taxon_id

  Arg [1]    : number (taxon_id)
  Example    : $gdbs = $gdba->fetch_all_by_taxon_id(1234);
  Description: Retrieves the genome db(s) using the NCBI taxon_id of the species.
  Returntype : Arrayref of Bio::EnsEMBL::Compara::GenomeDB
  Exceptions : thrown if $taxon_id is not given
  Caller     : general
  Status     : Stable

=cut

sub fetch_all_by_taxon_id {
    my ($self, $taxon_id) = @_;

    throw("taxon_id argument is required") unless($taxon_id);

    return $self->_id_cache->get_all_by_additional_lookup('taxon_id', $taxon_id);
}


=head2 fetch_by_registry_name

  Arg [1]    : string $name
  Arg [2]    : string $component (optional)
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
  my ($self, $name, $component) = @_;

  unless($name) {
    throw('name arguments are required');
  }

  my $species_db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($name, "core");
  if (!$species_db_adaptor) {
    throw("Cannot connect to core database for $name!");
  }

  return $self->fetch_by_core_DBAdaptor($species_db_adaptor, $component);
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

  assert_ref($slice, 'Bio::EnsEMBL::Slice', 'slice');
  unless ($slice->adaptor) {
    throw("[$slice] must have an adaptor");
  }

  my $core_dba = $slice->adaptor()->db();
  my $gdb = $self->fetch_by_core_DBAdaptor($core_dba);

  if (!$gdb) {
      # It may be that the slice belongs to a component
      my $all_comp_attr = $slice->get_all_Attributes('genome_component');
      if (@$all_comp_attr) {
          my $comp_name = $all_comp_attr->[0]->value;
          $gdb = $self->fetch_by_core_DBAdaptor($core_dba, $comp_name);
      }
  }
  # NOTE: this method could be "greedy" and return the component GenomeDB
  # instead of the principal one. See below

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


=head2 fetch_by_core_DBAdaptor

	Arg [1]     : Bio::EnsEMBL::DBSQL::DBAdaptor
        Arg [2]     : string $component (optional)
	Example     : my $gdb = $gdba->fetch_by_core_DBAdaptor($core_dba);
	Description : For a given core database adaptor object; this method will
	              return the GenomeDB instance
	Returntype  : Bio::EnsEMBL::Compara::GenomeDB
	Exceptions  : thrown if no name is found for the adaptor
	Caller      : general
	Status      : Stable

=cut

sub fetch_by_core_DBAdaptor {
    my ($self, $core_dba, $component) = @_;
    my $was_connected = $core_dba->dbc->connected;
    my $species_name = $core_dba->get_MetaContainer->get_production_name();
    return undef unless $species_name;
    my $species_assembly = $core_dba->assembly_name();
    $core_dba->dbc->disconnect_if_idle() unless $was_connected;
    return $self->fetch_by_name_assembly($species_name, $species_assembly, $component);
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
    return [grep {$_->is_polyploid} $self->_id_cache->cached_values()];
}


=head2 fetch_all_by_mixed_ref_lists

  Arg [-SPECIES_LIST] (opt)
              : Arrayref. List of species defined as GenomeDBs, genome_db_id, production or Registry name
  Arg [-TAXON_LIST] (opt)
              : Arrayref. List of taxa defined as NCBITaxons, taxon_id (internal and terminal) or name
  Example     : $genome_db_adaptor->fetch_all_by_mixed_ref_lists(-SPECIES_LIST => ['human'], -TAXON_LIST => ['Carnivora',10090]);
  Description : Fetch all the GenomeDBs that match any ref in the lists.
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::GenomeDB
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_by_mixed_ref_lists {
    my $self = shift;

    my ($species_list, $taxon_list) = rearrange([qw(SPECIES_LIST TAXON_LIST)], @_);

    my %unique_gdbs = ();

    # Find all the species. Accepted values are: GenomeDBs, genome_db_ids, and species names (incl. aliases)
    foreach my $s (@{wrap_array($species_list)}) {
        if (ref($s)) {
            assert_ref($s, 'Bio::EnsEMBL::Compara::GenomeDB', 'element of -SPECIES_LIST');
            $unique_gdbs{$s->dbID} = $s;
        } elsif (looks_like_number($s)) {
            $unique_gdbs{$s} = $self->fetch_by_dbID($s) || throw("Could not find a GenomeDB with dbID=$s");
        } else {
            my $g = $self->fetch_by_name_assembly($s);
               $g = $self->fetch_by_registry_name($s) unless $g;
            throw("Could not find a GenomeDB named '$s'") unless $g;
            $unique_gdbs{$g->dbID} = $g;
        }
    }

    # Find all the taxa. Accepted values are: NCBITaxons, taxon_ids, and taxon names
    my $ncbi_a = $self->db->get_NCBITaxonAdaptor();
    foreach my $t (@{wrap_array($taxon_list)}) {
        my $tax;
        if (ref($t)) {
            assert_ref($t, 'Bio::EnsEMBL::Compara::NCBITaxon', 'element of -TAXON_LIST');
            $tax = $t->dbID;
        } elsif (looks_like_number($t)) {
            $ncbi_a->fetch_node_by_taxon_id($t) || throw("Could not find a NCBITaxon with dbID=$t");
            $tax = $t;
        } else {
            my $ntax = $ncbi_a->fetch_node_by_name($t);
            throw("Could not find a NCBITaxon named '$t'") unless $ntax;
            $tax = $ntax->dbID;
        }
        foreach my $gdb (@{$self->fetch_all_by_ancestral_taxon_id($tax)}) {
            $unique_gdbs{$gdb->dbID} = $gdb;
        }
    }

    return [values %unique_gdbs];
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

    assert_ref($gdb, 'Bio::EnsEMBL::Compara::GenomeDB', 'gdb');

    if(my $reference_dba = $self->db->reference_dba()) {
        $reference_dba->get_GenomeDBAdaptor->store( $gdb );
    }

    if($self->_synchronise($gdb)) {
        return $self->update($gdb);
    } else {
        my $dbID = $self->generic_insert('genome_db', {
                'genome_db_id'      => $gdb->dbID,
                'name'              => $gdb->name,
                'assembly'          => $gdb->assembly,
                'genebuild'         => $gdb->genebuild,
                'has_karyotype'     => $gdb->has_karyotype,
                'is_high_coverage'  => $gdb->is_high_coverage,
                'taxon_id'          => $gdb->taxon_id,
                'genome_component'  => $gdb->genome_component,
                'strain_name'       => $gdb->strain_name,
                'display_name'      => $gdb->display_name,
                'locator'           => $gdb->locator,
                'first_release'     => $gdb->first_release,
                'last_release'      => $gdb->last_release,
            }, 'genome_db_id');
        $self->attach($gdb, $dbID);
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

    assert_ref($gdb, 'Bio::EnsEMBL::Compara::GenomeDB', 'gdb');

    if(my $reference_dba = $self->db->reference_dba()) {
        $reference_dba->get_GenomeDBAdaptor->update( $gdb );
    }

    $self->generic_update('genome_db',
        {
                'name'              => $gdb->name,
                'assembly'          => $gdb->assembly,
                'genebuild'         => $gdb->genebuild,
                'has_karyotype'     => $gdb->has_karyotype,
                'is_high_coverage'  => $gdb->is_high_coverage,
                'taxon_id'          => $gdb->taxon_id,
                'genome_component'  => $gdb->genome_component,
                'strain_name'       => $gdb->strain_name,
                'display_name'      => $gdb->display_name,
                'locator'           => $gdb->locator,
                'first_release'     => $gdb->first_release,
                'last_release'      => $gdb->last_release,
        }, {
            'genome_db_id' => $gdb->dbID()
        } );

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
        my $that_gdb = $self->fetch_by_core_DBAdaptor($db_adaptor);
        $that_gdb->db_adaptor($db_adaptor) if $that_gdb and not $that_gdb->{_db_adaptor};
    }

    my @missing = ();
    foreach my $genome_db (@{$self->fetch_all}) {
        next if $genome_db->{_db_adaptor};
        $genome_db->{_db_adaptor} = undef;
        push @missing, $genome_db;
    }
    warn("Cannot find all the core databases in the Registry. Be aware that getting Core objects from Compara is not possible for the following species/assembly: ".
        join(", ", map {sprintf('%s/%s', $_->name, $_->assembly)} @missing)."\n") if @missing;
}


######################################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseReleaseHistoryAdaptor #
######################################################################

=head2 retire_object

  Arg[1]      : Bio::EnsEMBL::Compara::GenomeDB
  Example     : $genome_db_adaptor->retire_object($gdb);
  Description : Mark the GenomeDB as retired, i.e. with a last_release older than the current version
                Also mark all the related SpeciesSets as retired
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub retire_object {
    my ($self, $gdb) = @_;
    # Update the fields in the table
    $self->SUPER::retire_object($gdb);
    # Also update the linked SpeciesSets
    my $ss_adaptor = $self->db->get_SpeciesSetAdaptor;
    foreach my $ss (@{$ss_adaptor->fetch_all_by_GenomeDB($gdb)}) {
        $ss_adaptor->retire_object($ss);
    }
}


=head2 make_object_current

  Arg[1]      : Bio::EnsEMBL::Compara::GenomeDB
  Example     : $genome_db_adaptor->make_object_current($gdb);
  Description : Mark the GenomeDB as current, i.e. with a defined first_release and an undefined last_release
                Also retire all the other GenomeDBs that have the same name
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub make_object_current {
    my ($self, $gdb) = @_;
    # Update the fields in the table
    $self->SUPER::make_object_current($gdb);
    # Also update the GenomeDBs with the same name
    foreach my $other_gdb (@{ $self->_id_cache->get_all_by_additional_lookup('name', lc $gdb->name) }) {
        # But of course not the given one
        next if $other_gdb->dbID == $gdb->dbID;
        # Be careful about polyploid genomes and their components
        # Let's not retire a component of $gdb, or vice-versa
        next if $gdb->is_polyploid and $other_gdb->genome_component and ($other_gdb->principal_genome_db->dbID == $gdb->dbID);
        next if $other_gdb->is_polyploid and $gdb->genome_component and ($gdb->principal_genome_db->dbID == $other_gdb->dbID);
        $self->retire_object($other_gdb);
    }
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
        g.strain_name
        g.display_name
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

    my $genome_db_list = $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::GenomeDB', [
            'dbID',
            'name',
            'assembly',
            '_taxon_id',
            'genebuild',
            'has_karyotype',
            'is_high_coverage',
            '_genome_component',
            '_strain_name',
            '_display_name',
            'locator',
            '_first_release',
            '_last_release',
        ] );

    # Here, we need to connect the genome_dbs to the Registry and to one another (polyploid genomes)
    my %gdb_per_key = map {$_->_get_unique_key => $_} (grep {not $_->genome_component} @$genome_db_list);
    foreach my $gdb (@$genome_db_list) {
        $gdb->sync_with_registry();
        next unless $gdb->genome_component;
        my $key = $gdb->_get_unique_key;
        $gdb_per_key{$key}->component_genome_dbs($gdb->genome_component, $gdb) if $gdb_per_key{$key};
    }

    return $genome_db_list;
}

############################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseFullAdaptor #
############################################################


sub _build_id_cache {
    my $self = shift;
    return Bio::EnsEMBL::Compara::DBSQL::Cache::GenomeDB->new($self);
}


package Bio::EnsEMBL::Compara::DBSQL::Cache::GenomeDB;

use base qw/Bio::EnsEMBL::DBSQL::Support::FullIdCache/;
use strict;
use warnings;

sub compute_keys {
    my ($self, $genome_db) = @_;
    return {
            ($genome_db->genome_component ? 'genome_component' : 'name_assembly') => $genome_db->_get_unique_key,

            # taxon_id -> GenoneDB
            $genome_db->taxon_id ? (taxon_id => $genome_db->taxon_id) : (),

            # name -> GenomeDB (excluding components)
            $genome_db->genome_component ? () : (name => lc $genome_db->name),

           }
}


1;

