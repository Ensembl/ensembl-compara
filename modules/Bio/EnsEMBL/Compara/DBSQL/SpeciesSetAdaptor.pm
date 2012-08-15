package Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor;

use strict;

use Scalar::Util qw(looks_like_number);
use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');


sub object_class {
    return 'Bio::EnsEMBL::Compara::SpeciesSet';
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

        # check whether all the GenomeDB objects have genome_db_ids:
    foreach my $genome_db (@{$species_set->genome_dbs}) {
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
    if ( my $stored_dbID = $self->find_species_set_id_by_GenomeDBs_mix( $species_set->genome_dbs ) ) {
        if($dbID and $dbID!=$stored_dbID) {
            die "Attempting to store an object with dbID=$dbID experienced a collision with same data but different dbID ($stored_dbID)";
        } else {
            $dbID = $stored_dbID;
        }
    } else {
        if($dbID) { # dbID is set in the object, but may refer to an object with different contents

            if($self->fetch_by_dbID( $dbID )) {
                die sprintf("Attempting to store an object with dbID=$dbID (ss=%s) experienced a collision with same dbID but different data", join("/", map {$_->dbID} @{$species_set->genome_dbs}  ));
            }

        } else { # grab a new species_set_id by using AUTO_INCREMENT:

            my $grab_id_sql = 'INSERT INTO species_set VALUES ()';
            $self->db->dbc->do( $grab_id_sql ) or die "Could not perform '$grab_id_sql'";

            if( $dbID = $self->dbc->db_handle->last_insert_id(undef, undef, 'species_set', 'species_set_id') ) {

                my $empty_sql = "DELETE FROM species_set where species_set_id = $dbID";
                $self->db->dbc->do( $empty_sql ) or die "Could not perform '$empty_sql'";
            } else {
                die "Failed to obtain a species_set_id for the species_set being stored";
            }
        }

        # Add the data into the DB
        my $sql = "INSERT INTO species_set (species_set_id, genome_db_id) VALUES (?, ?)";
        my $sth = $self->prepare($sql);
        foreach my $genome_db (@{$species_set->genome_dbs}) {
            $sth->execute($dbID, $genome_db->dbID);
        }
        $sth->finish();
    }

    $self->attach( $species_set, $dbID );

    $self->sync_tags_to_database( $species_set );

    return $species_set;
}


sub _tables {
    my $self = shift @_;

    return ( ['species_set', 'ss'] );
}


sub _columns {

        #warning _objs_from_sth implementation depends on ordering
    return qw (
        ss.species_set_id
        ss.genome_db_id
    );
}

sub _objs_from_sth {
    my ($self, $sth) = @_;

    my %ss_content_hash = ();
    my %ss_incomplete   = ();
    my $gdb_adaptor = $self->db->get_GenomeDBAdaptor;

    while ( my ($species_set_id, $genome_db_id) = $sth->fetchrow() ) {

            # gdb objects are already cached on the $gdb_adaptor level, so no point in re-caching them here
        if( my $gdb = $gdb_adaptor->fetch_by_dbID( $genome_db_id) ) {
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

    return \@ss_list;
}


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

    my $entries = $self->generic_fetch("sst.tag='$tag'", [[['species_set_tag', 'sst'], 'sst.species_set_id=ss.species_set_id', ['sst.tag', 'sst.value']]] );

    return $entries;
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

    my $entries = $self->generic_fetch("sst.tag='$tag' AND sst.value='$value'", [[['species_set_tag', 'sst'], 'sst.species_set_id=ss.species_set_id', ['sst.tag', 'sst.value']]] );

    return $entries;
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

    my $species_set_id = $self->find_species_set_id_by_GenomeDBs_mix( $genome_dbs );

    return $species_set_id && $self->fetch_by_dbID($species_set_id);
}


=head2 find_species_set_id_by_GenomeDBs_mix

  Arg [1]     : listref of Bio::EnsEMBL::Compara::GenomeDB objects or their dbIDs
  Example     : my $species_set = $species_set_adaptor->find_species_set_id_by_GenomeDBs_mix($genome_dbs);
  Description : Fetches the SpeciesSet object for that set of GenomeDBs
  Returntype  : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions  : thrown if a GenomeDB has no dbID. Warns if more than one SpeciesSet has
                this set of GenomeDBs
  Caller      : general

=cut

sub find_species_set_id_by_GenomeDBs_mix {
  my ($self, $genome_dbs) = @_;

  my @genome_db_ids = ();
  foreach my $genome_db (@$genome_dbs) {
    if(looks_like_number($genome_db)) {
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

  unless(@genome_db_ids) {
    warning("Empty genome_dbs list, nothing to look for");
    return undef;
  }
  my $gc = join(',', sort {$a <=> $b} @genome_db_ids);

  my $sql = "SELECT species_set_id FROM species_set GROUP BY species_set_id HAVING GROUP_CONCAT(genome_db_id ORDER BY genome_db_id)='$gc'";
  my $sth = $self->prepare($sql);
  $sth->execute();
  my $all_rows = $sth->fetchall_arrayref();
  $sth->finish();

  if (!@$all_rows) {
    return undef;
  } elsif (@$all_rows > 1) {
    warning("Several SpeciesSets([$gc]) have been found, species_set_ids: ".join(', ', map {$_->[0]} @$all_rows));
  }
  return $all_rows->[0]->[0];
}


###################################
#
# tagging 
#
###################################

sub _tag_capabilities {
    return ("species_set_tag", undef, "species_set_id", "dbID");
}


1;
