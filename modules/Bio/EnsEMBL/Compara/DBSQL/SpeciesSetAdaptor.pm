package Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor;

use strict;

use Scalar::Util qw(looks_like_number);
use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::DBSQL::BaseAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');


=head2 store

  Arg [1]     : Bio::EnsEMBL::Compara::SpeciesSet object
  Example     : my $species_set = $species_set_adaptor->store($species_set);
  Description : Stores the object in the database. Checks that all the
                Bio::EnsEMBL::Compara::GenomeDB objects in the genome_dbs
                array have a dbID. Assigns a species_set_id if the object hasn't
                got one (this locks the table). Also stores the tags if any
  Returntype  : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions  : thrown if a GenomeDB has no dbID
  Caller      : general
  Status      : Stable

=cut

sub store {
  my ($self, $species_set) = @_;

  # First check all the GenomeDB objects
  foreach my $genome_db (@{$species_set->genome_dbs}) {
    throw if (!$genome_db->dbID);
  }

  # Check that the data do not exist already in the DB.
  my $existing_species_set = $self->fetch_by_GenomeDBs($species_set->genome_dbs);

  my $species_set_id;
  
  if ($existing_species_set) {
    $species_set_id = $existing_species_set->dbID;
  } else {
    # Check the species_set_id. Assign it if it doesn't exist
    $species_set_id = $species_set->dbID;
    my $lock_tables = 0;
    if (!$species_set_id) {
      $lock_tables = 1;
      $self->dbc->do("LOCK TABLES species_set WRITE");

      my $sql = "SELECT MAX(species_set_id) FROM species_set";
      my $sth = $self->prepare($sql);
      $sth->execute();
      $species_set_id = ($sth->fetchrow_array() or 0);
      $species_set_id++;
    }
    throw if (!$species_set_id);

    # Add the data into the DB
    my $sql = qq{
            INSERT INTO species_set(species_set_id,genome_db_id)
            VALUES (?, ?)
        };
    my $sth = $self->prepare($sql);
    foreach my $genome_db (@{$species_set->genome_dbs}) {
      my $genome_db_id = $genome_db->dbID;
#       print "$species_set_id, $genome_db_id\n";
      $sth->execute($species_set_id, $genome_db_id);
    }
    $sth->finish();
    
    # Only unlock the table after adding the entries to make sure that not 2 threads try to use the species_set_id
    if ($lock_tables) {
      $self->dbc->do("UNLOCK TABLES");
    }
  }
  $species_set->dbID($species_set_id);

  $self->sync_tags_to_database($species_set);

  return $species_set;
}


sub _need_tags_for_query {
    my $self = shift @_;

    if(@_) {
        $self->{'_need_tags_for_query'} = shift @_;
    }
    return $self->{'_need_tags_for_query'};
}

sub _tables {
    my $self = shift @_;

    return (
        ['species_set', 'ss'],
        $self->_need_tags_for_query ? ( ['species_set_tag', 'sst'] ) : ()
    );
}

sub _left_join {
    my $self = shift @_;

    return $self->_need_tags_for_query ? ( [ 'species_set_tag', "sst.species_set_id = ss.species_set_id" ] ) : ();
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

    $self->_need_tags_for_query(1);
    my $entries = $self->generic_fetch( "sst.tag='$tag'" );
    $self->_need_tags_for_query(0);

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

    $self->_need_tags_for_query(1);
    my $entries = $self->generic_fetch( "sst.tag='$tag' AND sst.value='$value'" );
    $self->_need_tags_for_query(0);

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
    return undef;
  }

  my $sql = qq{
          SELECT
            species_set_id,
            COUNT(*) as count
          FROM
            species_set
          WHERE
            genome_db_id in (}.join(",", @genome_db_ids).qq{)
          GROUP BY species_set_id
          HAVING count = }.(scalar(@genome_db_ids));
  my $sth = $self->prepare($sql);
  $sth->execute();
  my $all_rows = $sth->fetchall_arrayref();
  $sth->finish();

  if (!@$all_rows) {
    return undef;
  }
  my $species_set_ids = [map {$_->[0]} @$all_rows];

  ## Keep only the species_set which does not contain any other genome_db_id
  $sql = qq{
          SELECT
            species_set_id,
            COUNT(*) as count
          FROM
            species_set
          WHERE
            species_set_id in (}.join(",", @$species_set_ids).qq{)
          GROUP BY species_set_id
          HAVING count = }.(scalar(@genome_db_ids));
  $sth = $self->prepare($sql);
  $sth->execute();

  $all_rows = $sth->fetchall_arrayref();

  $sth->finish();

  if (!@$all_rows) {
    return undef;
  } elsif (@$all_rows > 1) {
    warning("Several species_set_ids have been found for genome_db_ids (".
        join(",", @genome_db_ids)."): ".join(",", map {$_->[0]} @$all_rows));
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
