package EnsEMBL::Web::DBSQL::ProductionAdaptor;

### A simple adaptor to fetch the changelog from the ensembl_production database
### For full CRUD functionality, see public-plugins/orm, which uses the Rose::DB::Object
### ORM framework

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;

sub new {
  my ($class, $hub) = @_;

    my $self = {
    'NAME' => $hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'},
    'HOST' => $hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'HOST'},
    'PORT' => $hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'PORT'},
    'USER' => $hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'USER'},
    'PASS' => $hub->species_defs->multidb->{'DATABASE_PRODUCTION'}{'PASS'},
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

sub fetch_changelog {
### Selects all changes for a given release and returns them as an arrayref of hashes
  my ($self, $criteria) = @_;
  my $changes = [];
  return [] unless $self->db;

  my ($sql, $sql2);
  my @args = ($criteria->{'release'});

  if ($criteria->{'species'}) {
    $sql = qq(
      SELECT
        c.changelog_id, c.title, c.content, c.team
      FROM
        changelog as c, species as s, changelog_species as cs 
      WHERE 
        c.changelog_id = cs.changelog_id
        AND s.species_id = cs.species_id
        AND c.title != ''
        AND c.content != ''
        AND c.status = 'handed_over'
        AND c.release_id = ?
        AND s.name = ?
      ORDER BY
        c.team,
        c.priority DESC
    );
    push @args, $criteria->{'species'};
  }
  else {
    $sql = qq(
      SELECT
        c.changelog_id, c.title, c.content, c.team
      FROM
        changelog as c
      WHERE 
        c.release_id = ?
        AND c.title != ''
        AND c.content != ''
        AND c.status = 'handed_over'
      ORDER BY
        c.team,
        c.priority DESC
    );
  }

  my $sth = $self->db->prepare($sql);
  $sth->execute(@args);

  ## Prepare species SQL
  if ($criteria->{'species'}) {
    $sql2 = qq(
      SELECT
        species_id, db_name, web_name
      FROM
        species
      WHERE
        s.db_name = ?
    );
  }
  else {
    $sql2 = qq(
      SELECT
        s.species_id, s.db_name, s.web_name
      FROM
        species as s, changelog_species as cs
      WHERE
        s.species_id = cs.species_id
        AND cs.changelog_id = ?
    );
  }
  my $sth2 = $self->db->prepare($sql2);

  while (my @data = $sth->fetchrow_array()) {
    
    ## get the species info for this record
    my $species = [];
    my $arg2 = $criteria->{'species'} || $data[0];
    $sth2->execute($arg2);
    while (my @sp = $sth2->fetchrow_array()) {
      push @$species, {
        'id'          => $sp[0],
        'name'        => $sp[1],
        'common_name' => $sp[2],
      };
    }

    my $record = {
      'id'            => $data[0],
      'title'         => $data[1],
      'content'       => $data[2],
      'team'          => $data[3],
      'species'       => $species,
    };
    push @$changes, $record;
  }

  return $changes;
}


1;
