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

package Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor;

use strict;
use warnings;

use DBI qw(:sql_types);

use Scalar::Util qw(looks_like_number);

use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::ApiVersion;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseReleaseHistoryAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');

# NOTE: the "size" column is write-only


#############################################################
# Implements Bio::EnsEMBL::Compara::RunnableDB::ObjectStore #
#############################################################

sub object_class {
    return 'Bio::EnsEMBL::Compara::SpeciesSet';
} 



#################
# Class methods #
#################

sub _ids_string {

    my $genome_dbs = shift;
    my %genome_db_ids;
    foreach my $genome_db (@{$genome_dbs}) {
        if (looks_like_number($genome_db)) {
            warning("GenomeDB $genome_db is selected multiple times !") if $genome_db_ids{$genome_db};
            $genome_db_ids{$genome_db} = 1;
        } elsif($genome_db and $genome_db->isa("Bio::EnsEMBL::Compara::GenomeDB")) {
            if(my $genome_db_id = $genome_db->dbID) {
                warning("GenomeDB $genome_db_id is selected multiple times !") if $genome_db_ids{$genome_db_id};
                $genome_db_ids{$genome_db_id} = 1;
            } else {
                throw "[$genome_db] must have a dbID";
            }
        } else {
            throw "[$genome_db] must be a Bio::EnsEMBL::Compara::GenomeDB object or the corresponding dbID";
        }
    }

    my @sorted_ids = sort {$a <=> $b} keys %genome_db_ids;
    my $string_ids = join ',', @sorted_ids;
    return $string_ids || '';
}


##################
# store* methods #
##################

sub _synchronise {
    my ($self, $species_set) = @_;

    assert_ref($species_set, 'Bio::EnsEMBL::Compara::SpeciesSet', 'species_set');

    my $dbID        = $species_set->dbID;
    my $genome_dbs  = $species_set->genome_dbs;

    if ( my $stored_ss = $self->fetch_by_GenomeDBs( $genome_dbs ) ) {
        my $stored_dbID = $stored_ss->dbID;
        if($dbID and $dbID!=$stored_dbID) {
            die "Attempting to store an object with dbID=$dbID experienced a collision with same data but different dbID ($stored_dbID)\n";
        } else {
            $self->attach($species_set, $stored_dbID);
            return $stored_ss;
        }
    } else {
        if($dbID and $self->fetch_by_dbID( $dbID )) {
            die sprintf("Attempting to store an object with dbID=$dbID (ss=%s) experienced a collision with same dbID but different data\n", join("/", map {$_->dbID} @$genome_dbs ));
        } else {
            return undef;   # not found, safe to insert
        }
    }
}


=head2 store

  Arg [1]     : Bio::EnsEMBL::Compara::SpeciesSet object
  Example     : my $species_set = $species_set_adaptor->store($species_set);
  Description : Stores the SpeciesSet object in the database unless it has been stored already; updates the dbID of the object.
                    Also makes sure tags are stored.
  Returntype  : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions  : thrown if a GenomeDB has no dbID
  Caller      : general
  Status      : Stable

=cut

sub store {
    my ($self, $species_set, $store_components_first) = @_;

    my $genome_dbs = $species_set->genome_dbs;

        # check whether all the GenomeDB objects have genome_db_ids:
    foreach my $genome_db (@$genome_dbs) {
        if( $store_components_first ) {
            my $genome_db_adaptor = $self->db->get_GenomeDBAdaptor();
            $genome_db_adaptor->store( $genome_db );
        }
        
        if( !$genome_db->dbID ) {
            throw("GenomeDB ".$genome_db->toString." is missing a dbID");
        }
    }

    if($self->_synchronise($species_set)) {
        $self->update_header($species_set);

    } else {
        my $dbID = $self->generic_insert('species_set_header', {
                'species_set_id'=> $species_set->dbID,
                'name'          => $species_set->name,
                'size'          => $species_set->size,
                'first_release' => $species_set->first_release,
                'last_release'  => $species_set->last_release,
            }, 'species_set_id');
        $self->attach($species_set, $dbID);

            # Add the data into the DB
        $self->generic_multiple_insert(
            'species_set',
            ['species_set_id', 'genome_db_id'],
            [map {[$dbID, $_->dbID]} @$genome_dbs]
        );

        $self->_id_cache->put($dbID, $species_set);
    }

    $self->attach( $species_set, $species_set->dbID );
    $self->sync_tags_to_database( $species_set );

    return $species_set;
}


=head2 update_header

  Example     : $species_set_adaptor->update_header();
  Description : Update the header of this species_set in the database
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub update_header {
    my ($self, $species_set) = @_;

    $self->generic_update('species_set_header',
        {
            'name'          => $species_set->name,
            'size'          => $species_set->size,
            'first_release' => $species_set->first_release,
            'last_release'  => $species_set->last_release,
        }, {
            'species_set_id'=> $species_set->dbID,
        } );
}



########################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor #
########################################################

sub _tables {
    return ( ['species_set_header', 'sh'], ['species_set', 'ss'] );
}

sub _left_join {
    return (
        ['species_set', 'sh.species_set_id = ss.species_set_id'],
    );
}

sub _columns {
    # warning _objs_from_sth implementation depends on ordering
    return qw (
        sh.species_set_id
        sh.name
        sh.first_release
        sh.last_release
        ss.genome_db_id
    );
}

sub _objs_from_sth {
    my ($self, $sth) = @_;

    my %ss_header       = ();
    my %ss_content_hash = ();
    my %ss_incomplete   = ();
    my $gdb_cache = $self->db->get_GenomeDBAdaptor->_id_cache;

    while ( my ($species_set_id, $name, $first_release, $last_release, $genome_db_id) = $sth->fetchrow() ) {

        if (!$genome_db_id) {
            # This is the NULL row added by the LEFT JOIN
            # It means that the set is empty
            $ss_content_hash{$species_set_id} = [];
        } elsif( my $gdb = $gdb_cache->get($genome_db_id) ) { # gdb objects are already cached on the $gdb_adaptor level, so no point in re-caching them here
            push @{$ss_content_hash{$species_set_id}}, $gdb;
        } else {
            warning("Species set with dbID=$species_set_id is missing genome_db entry with dbID=$genome_db_id, so it will not be fetched");
            $ss_incomplete{$species_set_id}++;
        }
        $ss_header{$species_set_id} = [$name, $first_release, $last_release];
    }

    my @ss_list;
    while (my ($species_set_id, $species_set_contents) = each %ss_content_hash) {
        unless($ss_incomplete{$species_set_id}) {
            my ($name, $first_release, $last_release) = @{$ss_header{$species_set_id}};
            push @ss_list, Bio::EnsEMBL::Compara::SpeciesSet->new_fast( {
                genome_dbs => $species_set_contents,
                dbID       => $species_set_id,
                adaptor    => $self,
                _name      => $name,
                _first_release  => $first_release,
                _last_release   => $last_release,
            } );
        }
    }

    return \@ss_list;
}

sub _uncached_fetch_by_dbID {
    my ($self, $id) = @_;
    $self->bind_param_generic_fetch($id, SQL_INTEGER);
    # Cannot use generic_fetch_one because it adds "LIMIT 1" and only the first genome_db would be listed
    return $self->generic_fetch('sh.species_set_id = ?')->[0];
}


###################
# fetch_* methods #
###################

=head2 fetch_all_by_tag

  Arg [1]     : string $tag
  Example     : my $species_sets = $species_set_adaptor->fetch_all_by_tag('taxon_id');
  Description : Fetches the SpeciesSet object that have this tag
  Returntype  : listref of Bio::EnsEMBL::Compara::SpeciesSet objects
  Exceptions  : None
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_by_tag {
    my ($self, $tag) = @_;

    my $all_objects = $self->fetch_all();
    $self->_load_tagvalues_multiple($all_objects, 1);
    return [grep {$_->has_tag($tag)} @$all_objects];
}


=head2 fetch_all_by_tag_value

  Arg [1]     : string $tag
  Arg [2]     : string $value
  Example     : my $species_set = $species_set_adaptor->fetch_by_tag_value('color', 'red');
  Description : Fetches the SpeciesSet object with that tag-value pair. If more than one
                species_set exists with this tag-value pair, returns the species_set
                with the largest species_set_id
  Returntype  : listref of Bio::EnsEMBL::Compara::SpeciesSet objects
  Exceptions  : None
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_by_tag_value {
    my ($self, $tag, $value) = @_;

    # Only scalar values are accepted
    return [] if ref $value;

    my $all_objects = $self->fetch_all();
    $self->_load_tagvalues_multiple($all_objects, 1);
    return [grep {$_->has_tag($tag) && ($_->get_value_for_tag($tag) eq $value)} @$all_objects];
}


=head2 fetch_by_GenomeDBs

  Arg [1]     : listref of Bio::EnsEMBL::Compara::GenomeDB objects or their dbIDs
  Example     : my $species_set = $species_set_adaptor->fetch_by_GenomeDBs($genome_dbs);
  Description : Fetches the SpeciesSet object for that set of GenomeDBs
  Returntype  : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions  : thrown if a GenomeDB has no dbID. Warns if more than one SpeciesSet has
                this set of GenomeDBs
  Caller      : general

=cut

sub fetch_by_GenomeDBs {
    my ($self, $genome_dbs) = @_;

    return $self->_id_cache->get_by_additional_lookup('genome_db_ids', _ids_string($genome_dbs));
}


=head2 fetch_all_by_name

  Arg [1]     : string $species_set_name
  Example     : my $species_sets = $species_set_adaptor->fetch_all_by_name('mammals');
  Description : Fetches the "collection" SpeciesSet object with that name
  Returntype  : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions  : thrown if $species_set_name is missing
  Caller      : general

=cut

sub fetch_all_by_name {
    my ($self, $species_set_name) = @_;

    throw('$species_set_name is required') unless $species_set_name;

    return $self->_id_cache->get_all_by_additional_lookup('name', $species_set_name);
}


=head2 fetch_all_by_GenomeDB

  Arg  1     : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : my $species_sets = $ssa->fetch_all_by_genome_db($genome_db)
  Description: Retrieve all the Bio::EnsEMBL::Compara::SpeciesSet objects
               which includes the genome defined by the Bio::EnsEMBL::Compara::GenomeDB
               object or the genome_db_id in the species_set
  Returntype : listref of Bio::EnsEMBL::Compara::SpeciesSet objects
  Exceptions : wrong argument throws
  Caller     :

=cut

sub fetch_all_by_GenomeDB {
    my ($self, $genome_db) = @_;

    assert_ref($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB', 'genome_db');

    my $genome_db_id = $genome_db->dbID or throw "[$genome_db] must have a dbID";

    return $self->_id_cache->get_all_by_additional_lookup(sprintf('genome_db_%d', $genome_db_id), 1);
}



###########################################
# Interface for "collection" species sets #
###########################################

=head2 fetch_collection_by_name

  Arg [1]     : string $collection
  Example     : my $collection = $species_set_adaptor->fetch_collection_by_name('ensembl');
  Description : Fetches the "collection" SpeciesSet object with that name
  Returntype  : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions  : thrown if $collection is missing
  Caller      : general

=cut

sub fetch_collection_by_name {
    my ($self, $collection) = @_;

    throw('$collection is required') unless $collection;

    my $all_ss = $self->fetch_all_by_name("collection-$collection");
    return $self->_find_most_recent($all_ss);
}


=head2 update_collection

  Arg[1]      : string $collection_name
  Arg[2]      : Bio::EnsEMBL::Compara::SpeciesSet $old_ss: The old "collection" species-set
  Arg[3]      : arrayref of Bio::EnsEMBL::Compara::GenomeDB $new_genome_dbs: The list of GenomeDBs the new collection should contain
  Example     : my $new_collection_ensembl = $species_set_adaptor->update_collection($collection_ensembl, $old_collection_object, $new_genome_db]);
  Description : Creates a new collection species-set that contains the new list of GenomeDBs
                The method assumes that all the species names in $new_genome_dbs are different
  Returntype  : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub update_collection {
    my ($self, $collection_name, $old_ss, $new_genome_dbs) = @_;

    my $gdb_a = $self->db->get_GenomeDBAdaptor;
    my $mlss_a = $self->db->get_MethodLinkSpeciesSetAdaptor;

    my $species_set = $self->fetch_by_GenomeDBs($new_genome_dbs);

    # Make or update $species_set, with the correct name
    if ($species_set) {
        # The new species-set already exists in the database
        if ($species_set->name) {
            if ($species_set->name ne "collection-$collection_name") {
                die sprintf("The species-set for the new '%s' collection content already exists and but has the name '%s' instead of 'collection-%s'. Cannot store the collection\n", $collection_name, $species_set->name, $collection_name);
            }
        } else {
            $species_set->name("collection-$collection_name");
            $self->update_header($species_set);
        }
    } else {
        $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new( -GENOME_DBS => $new_genome_dbs, -NAME => "collection-$collection_name" );
        $self->store($species_set);
    }

    if ($old_ss and ($old_ss->dbID != $species_set->dbID)) {
        if (not $old_ss->has_been_released) {
            # $old_ss is not used, so we could delete it
            # Let's change its name instead
            $old_ss->name('tmp'.$old_ss->name);
            $self->update_header($old_ss);
        }
    }

    return $species_set;
}

######################################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseReleaseHistoryAdaptor #
######################################################################

=head2 retire_object

  Arg[1]      : Bio::EnsEMBL::Compara::SpeciesSet
  Example     : $species_set_adaptor->retire_object($ss);
  Description : Mark the SpeciesSet as retired, i.e. with a last_release older than the current version
                Also mark all the related MethodLinkSpeciesSets as retired
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub retire_object {
    my ($self, $ss) = @_;
    # Update the fields in the table
    $self->SUPER::retire_object($ss);
    # Also update the linked MethodLinkSpeciesSets
    my $mlss_adaptor = $self->db->get_MethodLinkSpeciesSetAdaptor;
    foreach my $mlss (@{$mlss_adaptor->fetch_all_by_species_set_id($ss->dbID)}) {
        $mlss_adaptor->retire_object($mlss);
    }
}


=head2 make_object_current

  Arg[1]      : Bio::EnsEMBL::Compara::SpeciesSet
  Example     : $species_set_adaptor->make_object_current($ss);
  Description : Mark the SpeciesSet as current, i.e. with a defined first_release and an undefined last_release
                Also mark all the contained GenomeDBs as current
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub make_object_current {
    my ($self, $ss) = @_;
    # Update the fields in the table
    $self->SUPER::make_object_current($ss);
    # Also update the linked GenomeDBs
    my $gdb_adaptor = $self->db->get_GenomeDBAdaptor;
    foreach my $gdb (@{$ss->genome_dbs}) {
        $gdb_adaptor->make_object_current($gdb);
    }
}


#######################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::TagAdaptor #
#######################################################

sub _tag_capabilities {
    return ('species_set_tag', undef, 'species_set_id', 'dbID', 'tag', 'value');
}

############################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseFullAdaptor #
############################################################


sub _build_id_cache {
    my $self = shift;
    return Bio::EnsEMBL::Compara::DBSQL::Cache::SpeciesSet->new($self);
}


package Bio::EnsEMBL::Compara::DBSQL::Cache::SpeciesSet;


use base qw/Bio::EnsEMBL::DBSQL::Support::FullIdCache/;
use strict;
use warnings;

sub support_additional_lookups {
    return 1;
}

sub compute_keys {
    my ($self, $ss) = @_;
    return {
        genome_db_ids => Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor::_ids_string($ss->genome_dbs),
        name => $ss->name,
        (map {sprintf('genome_db_%d', $_->dbID) => 1} @{$ss->genome_dbs()}),
    }
}




1;
