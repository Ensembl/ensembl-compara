package EnsEMBL::Web::DBSQL::WebsiteAdaptor;

### A simple adaptor to fetch news and help from the ensembl_website database
### For full CRUD functionality, see public-plugins/orm, which uses the Rose::DB::Object
### ORM framework

use strict;
use warnings;
no warnings 'uninitialized';

use DBI;

sub new {
  my ($class, $hub) = @_;

    my $self = {
    'NAME' => $hub->species_defs->multidb->{'DATABASE_WEBSITE'}{'NAME'},
    'HOST' => $hub->species_defs->multidb->{'DATABASE_WEBSITE'}{'HOST'},
    'PORT' => $hub->species_defs->multidb->{'DATABASE_WEBSITE'}{'PORT'},
    'USER' => $hub->species_defs->multidb->{'DATABASE_WEBSITE'}{'USER'},
    'PASS' => $hub->species_defs->multidb->{'DATABASE_WEBSITE'}{'PASS'},
  };
  bless $self, $class;
  return $self;
}

sub db {
  my $self = shift;
  $self->{'dbh'} ||= DBI->connect(
      "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
      $self->{'USER'}, "$self->{'PASS'}"
  );
  return $self->{'dbh'};
}

sub fetch_release {
  my ($self, $release_id) = @_;

  my $sql = qq(
    SELECT
      number, date, archive
    FROM
      ens_release
    WHERE
      release_id = ?
    LIMIT 1
  );

  my $sth = $self->db->prepare($sql);
  $sth->execute($release_id);

  my $record;
  while (my @data = $sth->fetchrow_array()) {
    $record = {
      'id'      => $data[0],
      'date'    => $data[1],
      'archive' => $data[2],
    };
  }
  return $record;
}

sub fetch_news {
### Selects all news items for a given release and returns them as an arrayref of hashes
  my ($self, $criteria) = @_;
  my $news_items = [];

  my ($sql, $sql2);
  my @args = ($criteria->{'release'});

  if ($criteria->{'species'}) {
    $sql = qq(
      SELECT
        i.news_item_id, i.title, i.content, c.news_category_id, c.name
      FROM
        news_item as i, news_category as c, species as s, item_species as x
      WHERE 
        i.news_category_id = c.news_category_id
        AND i.news_item_id = x.news_item_id
        AND s.species_id = x.species_id
        AND i.status = 'published'
        AND i.release_id = ?
        AND s.name = ?
      ORDER BY
        c.priority, i.priority
    );
    push @args, $criteria->{'species'};
  }
  else {
    $sql = qq(
      SELECT
        i.news_item_id, i.title, i.content, c.news_category_id, c.name
      FROM
        news_item as i, news_category as c
      WHERE 
        i.news_category_id = c.news_category_id
        AND i.status = 'published'
        AND i.release_id = ?
      ORDER BY
        c.priority, i.priority
    );
  }

  if ($criteria->{'limit'}) {
    $sql .= " LIMIT ?";
    push @args, $criteria->{'limit'};
  }

  my $sth = $self->db->prepare($sql);
  $sth->execute(@args);

  ## Prepare species SQL
  if ($criteria->{'species'}) {
    $sql2 = qq(
      SELECT
        species_id, name, common_name
      FROM
        species
      WHERE
        s.species_id = ?
    );
  }
  else {
    $sql2 = qq(
      SELECT
        s.species_id, s.name, s.common_name
      FROM
        species as s, item_species as i
      WHERE
        s.species_id = i.species_id
        AND i.news_item_id = ?
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
      'category_id'   => $data[3],
      'category_name' => $data[4],
      'species'       => $species,
    };
    push @$news_items, $record;
  }

  return $news_items;
}


1;
