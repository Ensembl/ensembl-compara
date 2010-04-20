package Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Utils::Exception;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 new

  Arg [1]    : list of args to super class constructor
  Example    : $ga_a = new Bio::EnsEMBL::Compara::SpeciesSetAdaptor($dbobj);
  Description: Creates a new SpeciesSetAdaptor.  This
               class should be instantiated through the get method on the 
               DBAdaptor rather than calling this method directly.
  Returntype : none
  Exceptions : none
  Caller     : Bio::EnsEMBL::DBSQL::DBConnection
  Status     : Stable

=cut

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  return $self;
}


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
  return $existing_species_set if ($existing_species_set);

  # Check the species_set_id. Assign it if it doesn't exist
  my $species_set_id = $species_set->dbID;
  my $lock_tables = 0;
  if (!$species_set_id) {
    $lock_tables = 1;
    $self->dbc->do("LOCK TABLES species_set WRITE");

    my $sql = "SELECT MAX(species_set_id) FROM species_set";
    my $sth = $self->prepare($sql);
    $sth->execute();
    $species_set_id = ($sth->fetchrow_array() or 0);
    $species_set_id++;
    $species_set->dbID($species_set_id);
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
#     print "$species_set_id, $genome_db_id\n";
    $sth->execute($species_set_id, $genome_db_id);
  }
  $sth->finish();
  
  # Only unlock the table after adding the entries to make sure that not 2 threads try to use the species_set_id
  if ($lock_tables) {
    $self->dbc->do("UNLOCK TABLES");
  }

  # Add the tags if any
  my $tag_value_hash = $species_set->get_tagvalue_hash();
  if ($tag_value_hash) {
    $sql = "INSERT INTO species_set_tag (species_set_id, tag, value) VALUES (?, ?, ?)";
    $sth = $self->prepare($sql);
    while (my ($tag, $value) = each %$tag_value_hash) {
#     print "$species_set_id, $tag, $value\n";
      $sth->execute($species_set_id, $tag, $value);
    }
    $sth->finish;
  }

  return $species_set;
}


=head2 fetch_by_dbID

  Arg [1]     : int $species_set_id
  Example     : my $species_set = $species_set_adaptor->fetch_by_dbID($species_set_id);
  Description : Fetches the SpeciesSet object with that internal ID
  Returntype  : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions  : None
  Caller      : general
  Status      : Stable

=cut

sub fetch_by_dbID {
  my ($self, $dbID) = @_;
  my $species_set; # returned object

  my $sql = qq{
          SELECT
              species_set_id,
              genome_db_id
          FROM
              species_set
          WHERE
              species_set_id = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($dbID);
  my ($species_set_id,$genome_db_id);
  $sth->bind_columns(\$species_set_id,\$genome_db_id);
  my $genome_dbs;
  while ($sth->fetch) {
    my $genome_db = $self->db->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
    push(@$genome_dbs, $genome_db) if (defined($genome_db));
  }
  $sth->finish();

  if (!defined($genome_dbs)) {
    # There are situations when the genome_db will not exist, but
    # still makes sense to do the query -- mostly production
    $DB::single=1;1;
  }
  ## Create the object
  $species_set = new Bio::EnsEMBL::Compara::SpeciesSet
    (-adaptor => $self,
     -dbID => $dbID,
     -genome_dbs => $genome_dbs);
  $self->_load_tagvalues($species_set);

  return $species_set;
}


=head2 fetch_by_tag_value

  Arg [1]     : string $tag
  Arg [2]     : string $value
  Example     : my $species_set = $species_set_adaptor->fetch_by_tag_value("name", "primates");
  Description : Fetches the SpeciesSet object with that tag-value pair. If more than one
                species_set exists with this tag-value pair, returns the species_set
                with the largest species_set_id
  Returntype  : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions  : None
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_by_tag_value {
  my ($self, $tag, $value) = @_;
  my $species_sets; # returned object

  my $sql = qq{
          SELECT
              species_set_id
          FROM
              species_set_tag
          WHERE
              tag = ?
          AND
              value = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($tag,$value);
  my $species_set_id;
  $sth->bind_columns(\$species_set_id);
  while ($sth->fetch) {
    push(@$species_sets, $self->fetch_by_dbID($species_set_id));
  }

  $sth->finish;

  return $species_sets;

}


=head2 fetch_all_by_tag

  Arg [1]     : string $tag
  Example     : my $species_sets = $species_set_adaptor->fetch_all_by_tag("taxon_id");
  Description : Fetches the SpeciesSet object that have this tag
  Returntype  : listref of Bio::EnsEMBL::Compara::SpeciesSet objects
  Exceptions  : None
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_by_tag {
  my ($self, $tag) = @_;
  my $species_sets = []; # returned object

  my $sql = qq{
          SELECT
              species_set_id
          FROM
              species_set_tag
          WHERE
              tag = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($tag);
  my $species_set_id;
  $sth->bind_columns(\$species_set_id);
  while ($sth->fetch) {
    push(@$species_sets, $self->fetch_by_dbID($species_set_id));
  }
  $sth->finish;

  return $species_sets;

}


sub fetch_all_by_GenomeDBs {
  my ($self, $genome_dbs) = @_;
  return $self->fetch_by_GenomeDBs($genome_dbs);
}


=head2 fetch_by_GenomeDBs

  Arg [1]     : listref of Bio::EnsEMBL::Compara::GenomeDB objects
  Example     : my $species_set = $species_set_adaptor->fetch_by_GenomeDBs($genome_dbs);
  Description : Fetches the SpeciesSet object for that set of GenomeDBs
  Returntype  : Bio::EnsEMBL::Compara::SpeciesSet
  Exceptions  : thrown if a GenomeDB has no dbID. Warns if more than one SpeciesSet has
                this set of GenomeDBs
  Caller      : general
  Status      : Stable

=cut

sub fetch_by_GenomeDBs {
  my ($self, $genome_dbs) = @_;
  my $species_set_id;

  my $genome_db_ids;
  foreach my $genome_db (@$genome_dbs) {
    throw "[$genome_db] must be a Bio::EnsEMBL::Compara::GenomeDB object or the corresponding dbID"
        unless ($genome_db and $genome_db->isa("Bio::EnsEMBL::Compara::GenomeDB"));
    my $genome_db_id = $genome_db->dbID;
    throw "[$genome_db] must have a dbID" if (!$genome_db_id);
    push (@$genome_db_ids, $genome_db_id);
  }

  if (!defined($genome_db_ids)) {
    return undef;
  }

  my $sql = qq{
          SELECT
            species_set_id,
            COUNT(*) as count
          FROM
            species_set
          WHERE
            genome_db_id in (}.join(",", @$genome_db_ids).qq{)
          GROUP BY species_set_id
          HAVING count = }.(scalar(@$genome_db_ids));
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
          HAVING count = }.(scalar(@$genome_db_ids));
  $sth = $self->prepare($sql);
  $sth->execute();

  $all_rows = $sth->fetchall_arrayref();

  $sth->finish();

  if (!@$all_rows) {
    return undef;
  } elsif (@$all_rows > 1) {
    warning("Several species_set_ids have been found for genome_db_ids (".
        join(",", @$genome_db_ids)."): ".join(",", map {$_->[0]} @$all_rows));
  }
  $species_set_id = $all_rows->[0]->[0];

  my $species_set = $self->fetch_by_dbID($species_set_id);

  return $species_set;
}

sub fetch_all {
  my $self = shift;
  my $species_sets = [];

  my $sql = qq{
          SELECT
              distinct species_set_id
          FROM
              species_set
      };

  my $sth = $self->prepare($sql);
  $sth->execute();
  my ($species_set_id);
  $sth->bind_columns(\$species_set_id);
  while ($sth->fetch) {
    my $species_set = $self->fetch_by_dbID($species_set_id);
    push(@$species_sets, $species_set);
  }
  $sth->finish();

  return $species_sets;
}

###################################
#
# tagging 
#
###################################

sub _load_tagvalues {
  my $self = shift;
  my $species_set = shift;

  unless($species_set->isa('Bio::EnsEMBL::Compara::SpeciesSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::SpeciesSet] not a $species_set");
  }

  my $sth = $self->prepare("SELECT tag,value from species_set_tag where species_set_id=?");
  $sth->execute($species_set->dbID);
  while (my ($tag, $value) = $sth->fetchrow_array()) {
    $species_set->add_tag($tag,$value);
  }
  $sth->finish;
}


sub _store_tagvalue {
  my $self = shift;
  my $species_set_id = shift;
  my $tag = shift;
  my $value = shift;

  $value="" unless(defined($value));

  my $sql = "INSERT ignore into species_set_tag (species_set_id,tag) values ($species_set_id,\"$tag\")";
  #print("$sql\n");
  $self->dbc->do($sql);

  $sql = "UPDATE species_set_tag set value=\"$value\" where species_set_id=$species_set_id and tag=\"$tag\"";
  #print("$sql\n");
  $self->dbc->do($sql);
}


1;
