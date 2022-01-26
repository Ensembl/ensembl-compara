=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
      release_id, number, date, archive, online, description
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
      'id'          => $data[0],
      'version'     => $data[1],
      'date'        => $data[2],
      'archive'     => $data[3],
      'online'      => $data[4],
      'description' => $data[5],
    };
  }
  return $records;
}

sub fetch_archive_assemblies {
  my ($self, $first_archive) = @_;
  return unless $self->db;
  
  my @args;
  my $sql = qq(
    SELECT
      s.name, s.common_name, r.number, rs.assembly_name, rs.assembly_version
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

  my $sth = $self->db->prepare($sql);
  $sth->execute(@args);

  my $records = {};
  while (my @data = $sth->fetchrow_array()) {
    $records->{$data[0]}{$data[2]} = {
      'common_name'      => $data[1],
      'assembly'         => $data[3],
      'assembly_version' => $data[4],
    };
  }
  return $records;
}

sub fetch_archives_by_species {
  my ($self, $species) = @_;
  return unless $self->db && $species;
  my $records = {};
  
  my @args = ('Y', $species);

  ## First check for special archives
  my $sql = qq(
    SELECT
      r.release_id, r.date, r.archive, r.description, 
      rs.species_url, rs.assembly_name, rs.assembly_version, rs.initial_release, rs.last_geneset
    FROM
      ens_release as r,
      species as s,
      release_species as rs
    WHERE  
      r.release_id = rs.release_id
    AND
      s.species_id = rs.species_id
    AND
      r.release_id > 10000
    AND
      r.online = ?
    AND
      s.name = ?
    ORDER BY r.release_id DESC
  );

  my $sth = $self->db->prepare($sql);
  $sth->execute(@args);

  while (my @data = $sth->fetchrow_array()) {
    $records->{$data[0]} = {
      'date'            => $data[1],
      'archive'         => $data[2],
      'description'     => $data[3],
      'url'             => $data[4],
      'assembly'        => $data[5],
      'version'         => $data[6],
      'initial_release' => $data[7],
      'last_geneset'    => $data[8],
    };
  }

  ## Now get ordinary archives
  $sql = qq(
    SELECT
      r.number, r.date, r.archive, r.description, 
      rs.species_url, rs.assembly_name, rs.assembly_version, rs.initial_release, rs.last_geneset
    FROM
      ens_release as r,
      species as s,
      release_species as rs
    WHERE
      r.release_id = rs.release_id
    AND
      r.release_id < 10000
    AND
      s.species_id = rs.species_id
    AND
      r.online = ?
    AND
      s.name = ?
    ORDER BY r.release_id DESC
  );

  $sth = $self->db->prepare($sql);
  $sth->execute(@args);

  while (my @data = $sth->fetchrow_array()) {
    $records->{$data[0]} = {
      'date'            => $data[1],
      'archive'         => $data[2],
      'description'     => $data[3],
      'url'             => $data[4],
      'assembly'        => $data[5],
      'version'         => $data[6],
      'initial_release' => $data[7],
      'last_geneset'    => $data[8],
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
