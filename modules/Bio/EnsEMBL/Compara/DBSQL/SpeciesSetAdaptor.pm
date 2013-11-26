=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use Scalar::Util qw(looks_like_number);
use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');



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
    my @genome_db_ids;
    foreach my $genome_db (@{$genome_dbs}) {
        if (looks_like_number($genome_db)) {
            push @genome_db_ids, $genome_db;
        } elsif($genome_db and $genome_db->isa("Bio::EnsEMBL::Compara::GenomeDB")) {
            if(my $genome_db_id = $genome_db->dbID) {
                push @genome_db_ids, $genome_db_id;
            } else {
                throw "[$genome_db] must have a dbID";
            }
        } else {
            throw "[$genome_db] must be a Bio::EnsEMBL::Compara::GenomeDB object or the corresponding dbID";
        }
    }

    my @sorted_ids = sort {$a <=> $b} @genome_db_ids;
    my $string_ids = join ',', @sorted_ids;
    return $string_ids;
}


##################
# store* methods #
##################

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

    my $dbID = $species_set->dbID;
        # Could we have a species_set in the DB with the given contents already?
    if ( my $stored_ss = scalar(@$genome_dbs) && $self->fetch_by_GenomeDBs( $genome_dbs ) ) {
        my $stored_dbID = $stored_ss->dbID;
        if($dbID and $dbID!=$stored_dbID) {
            die "Attempting to store an object with dbID=$dbID experienced a collision with same data but different dbID ($stored_dbID)\n";
        } else {
            $dbID = $stored_dbID;
        }
    } else {
        if($dbID) { # dbID is set in the object, but may refer to an object with different contents

            if($self->fetch_by_dbID( $dbID )) {
                die sprintf("Attempting to store an object with dbID=$dbID (ss=%s) experienced a collision with same dbID but different data\n", join("/", map {$_->dbID} @$genome_dbs ));
            }

        } else { # grab a new species_set_id by using AUTO_INCREMENT:

            my $grab_id_sql = 'INSERT INTO species_set VALUES ()';
            $self->db->dbc->do( $grab_id_sql ) or die "Could not perform '$grab_id_sql'\n";

            if( $dbID = $self->dbc->db_handle->last_insert_id(undef, undef, 'species_set', 'species_set_id') ) {

                my $empty_sql = "DELETE FROM species_set where species_set_id = $dbID";
                $self->db->dbc->do( $empty_sql ) or die "Could not perform '$empty_sql'\n";
            } else {
                die "Failed to obtain a species_set_id for the species_set being stored\n";
            }
        }

            # Add the data into the DB
        my $sql = "INSERT INTO species_set (species_set_id, genome_db_id) VALUES (?, ?)";
        my $sth = $self->prepare($sql);
        foreach my $genome_db (@$genome_dbs) {
            $sth->execute($dbID, $genome_db->dbID);
        }
        $sth->finish();

        $self->_id_cache->put($dbID, $species_set);
    }

    $self->attach( $species_set, $dbID );
    $self->sync_tags_to_database( $species_set );

    return $species_set;
}



########################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor #
########################################################

sub _tables {
    return ( ['species_set', 'ss'] );
}


sub _columns {
    # warning _objs_from_sth implementation depends on ordering
    return qw (
        ss.species_set_id
        ss.genome_db_id
    );
}

sub _objs_from_sth {
    my ($self, $sth) = @_;

    my %ss_content_hash = ();
    my %ss_incomplete   = ();
    my $gdb_cache = $self->db->get_GenomeDBAdaptor->_id_cache;

    while ( my ($species_set_id, $genome_db_id) = $sth->fetchrow() ) {

            # gdb objects are already cached on the $gdb_adaptor level, so no point in re-caching them here
        if( my $gdb = $gdb_cache->get($genome_db_id) ) {
            push @{$ss_content_hash{$species_set_id}}, $gdb;
        } else {
            warning("Species set with dbID=$species_set_id is missing genome_db entry with dbID=$genome_db_id, so it will not be fetched");
            $ss_incomplete{$species_set_id}++;
        }
    }

    my @ss_list;
    while (my ($species_set_id, $species_set_contents) = each %ss_content_hash) {
        unless($ss_incomplete{$species_set_id}) {
            push @ss_list, Bio::EnsEMBL::Compara::SpeciesSet->new(
                -genome_dbs => $species_set_contents,
                -dbID       => $species_set_id,
                -adaptor    => $self,
            );
        }
    }

    $self->_load_tagvalues_multiple(\@ss_list, 1);
    return \@ss_list;
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

    return $self->_id_cache->get_all_by_additional_lookup(sprintf('has_tag_%s', lc $tag), 1);
}


=head2 fetch_all_by_tag_value

  Arg [1]     : string $tag
  Arg [2]     : string $value
  Example     : my $species_set = $species_set_adaptor->fetch_by_tag_value('name', 'primates');
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
    return $self->_id_cache->get_all_by_additional_lookup(sprintf('tag_%s', lc $tag), lc $value);
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



#######################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::TagAdaptor #
#######################################################

sub _tag_capabilities {
    return ("species_set_tag", undef, "species_set_id", "dbID");
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
        (map {sprintf('has_tag_%s', lc $_) => 1} $ss->get_all_tags()),
        (map {sprintf('tag_%s', lc $_) => lc $ss->get_value_for_tag($_)} $ss->get_all_tags()),
    }
}




1;
