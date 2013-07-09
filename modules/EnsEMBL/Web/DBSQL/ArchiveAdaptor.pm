package EnsEMBL::Web::DBSQL::ArchiveAdaptor;

### A simple adaptor to fetch archive from the ensembl_archive database
### For full CRUD functionality, see public-plugins/orm, which uses the Rose::DB::Object
### ORM framework

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;

sub new {
  my ($class, $hub) = @_;

    my $self = {
    'NAME' => $hub->species_defs->multidb->{'DATABASE_ARCHIVE'}{'NAME'},
    'HOST' => $hub->species_defs->multidb->{'DATABASE_ARCHIVE'}{'HOST'},
    'PORT' => $hub->species_defs->multidb->{'DATABASE_ARCHIVE'}{'PORT'},
    'USER' => $hub->species_defs->multidb->{'DATABASE_ARCHIVE'}{'USER'},
    'PASS' => $hub->species_defs->multidb->{'DATABASE_ARCHIVE'}{'PASS'},
  };
  bless $self, $class;
  return $self;
}

sub db {
  my $self = shift;
  return unless $self->{'NAME'};
  $self->{'dbh'} ||= DBI->connect(
      "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
      $self->{'USER'}, "$self->{'PASS'}"
  );
  return $self->{'dbh'};
}


sub fetch_release {
  my ($self, $release_id) = @_;
  my $records = $self->fetch_releases($release_id);
  return $records->[0];
}

sub fetch_releases {
  ## Allow a release argument so we can fetch a  single release 
  ## using the same function 
  my ($self, $release_id) = @_;
  return unless $self->db;
  
  my @args;
  my $sql = qq(
    SELECT
      number, date, archive, online
    FROM
      ens_release
  );
  if ($release_id) {
    $sql .= qq(
      WHERE
        release_id = ?
      LIMIT 1
    );
    @args = ($release_id);
  }
  else {
    $sql .= qq(
      ORDER BY release_id ASC
    );
  }

  my $sth = $self->db->prepare($sql);
  $sth->execute(@args);

  my $records = [];
  while (my @data = $sth->fetchrow_array()) {
    push @$records, {
      'id'      => $data[0],
      'date'    => $data[1],
      'archive' => $data[2],
      'online'  => $data[3],
    };
  }
  return $records;
}

sub fetch_archives {
  my ($self, $first_archive) = @_;
  return unless $self->db;
  
  my @args;
  my $sql = qq(
    SELECT
      r.number, r.date, r.archive, s.species_id, s.name, rs.assembly_name
    FROM
      ens_release as r,
      species as s,
      release_species as rs
    WHERE
      r.release_id = rs.release_id
    AND
      s.species_id = rs.species_id
  );
  if ($first_archive) {
    $sql .= qq(AND
      rs.release_id >= ?
    );
    @args = ($first_archive);
  }
  $sql .= qq(
    ORDER BY r.release_id DESC
  );

  my $sth = $self->db->prepare($sql);
  $sth->execute(@args);

  my $records = [];
  while (my @data = $sth->fetchrow_array()) {
    push @$records, {
      'id'            => $data[0],
      'date'          => $data[1],
      'archive'       => $data[2],
      'species_id'    => $data[3],
      'species_name'  => $data[4],
      'assembly'      => $data[5],
    };
  }
  return $records;
}

sub fetch_all_species {
  my $self = shift;
  my $species = [];
  return [] unless $self->db;

  my $sql = qq(
    SELECT 
      species_id, code, name, common_name
    FROM
      species
    WHERE
      online = ?
  );

  my $sth = $self->db->prepare($sql);
  $sth->execute('Y');

  while (my @data = $sth->fetchrow_array()) {
    push @$species, {
      'id'          => $data[0],
      'code'        => $data[1],
      'name'        => $data[2],
      'common_name' => $data[3],
    };
  }
  return $species;
}

1;
