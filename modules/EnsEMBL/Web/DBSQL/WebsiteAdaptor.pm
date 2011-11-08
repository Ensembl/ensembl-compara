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
  return unless $self->{'NAME'};
  $self->{'dbh'} ||= DBI->connect(
      "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
      $self->{'USER'}, "$self->{'PASS'}"
  );
  return $self->{'dbh'};
}

##---------------- HELP ------------------------

sub search_help {
  my ($self, $string, $type) = @_;
  return unless $self->db;
  my $ids = [];

  my $like = '%'.$string.'%';
  my @args = ('live', $like, $like); ## checking two fields for same string

  my $sql = qq(
    SELECT
      help_record_id
    FROM
      help_record
    WHERE
      status = ? 
      AND (keyword like ? OR data like ?)
  );

  if ($type) {
    push @args, $type;
    $sql .= ' AND type = ?';
  }

  $sql .= ' ORDER BY type, helpful DESC, not_helpful ASC ';

  my $sth = $self->db->prepare($sql);
  $sth->execute(@args);

  while (my @data = $sth->fetchrow_array()) {
    push @$ids, $data[0];
  }
  return $ids;
}

sub fetch_help_by_ids {
  my ($self, $ids) = @_;
  return unless $self->db;
  my $records = [];

  ## For some reason, DBI doesn't like 'IN' arrays passed
  ## as bound parameters - either that or I'm doing it wrong!
  my $id_string = join(', ', @$ids);
  my $sql = qq(
    SELECT
      help_record_id, type, data
    FROM
      help_record
    WHERE
      status = 'live'
      AND help_record_id IN ($id_string)
    ORDER BY type, helpful DESC, not_helpful ASC
  );

  my $sth = $self->db->prepare($sql);
  $sth->execute();

  while (my @data = $sth->fetchrow_array()) {
    my $record = {
      'id'    => $data[0],
      'type'  => $data[1],
    };
    if ($data[2]) {
      my $extra = eval($data[2]);
      while (my ($k, $v) = each(%$extra)) {
        $record->{$k} = $v;
      }
    }
    push @$records, $record;
  }
  return $records;
}

sub fetch_faqs {
  my ($self, $criteria) = @_;
  return [] unless $self->db;
  my $records = [];

  my @args = ('live', 'faq');
  my $sql = qq(
    SELECT
      help_record_id, data
    FROM
      help_record
    WHERE
      status = ?
      AND type = ? 
  );

  ## Might seem a bit superfluous to add this to the above query
  ## but we don't want to publish non-live content by accident!
  if ($criteria->{'id'}) {
    $sql .= ' AND help_record_id = ? ';
    push @args, $criteria->{'id'};
  }
  elsif ($criteria->{'kw'}) {
    $sql .= ' AND keyword = ? ';
    push @args, $criteria->{'kw'};
  }

  $sql .= ' ORDER BY helpful DESC, not_helpful ASC ';

  if ($criteria->{'limit'}) {
    $sql .= ' LIMIT ?';
    push @args, $criteria->{'limit'};
  }

  my $sth = $self->db->prepare($sql);
  $sth->execute(@args);

  while (my @data = $sth->fetchrow_array()) {
    my $record = {
      'id'    => $data[0],
    };
    if ($data[1]) {
      my $extra = eval($data[1]);
      while (my ($k, $v) = each(%$extra)) {
        $record->{$k} = $v;
      }
    }
    push @$records, $record;
  }
  return $records;
}

sub fetch_movies {
  my $self = shift;
  return unless $self->db;
  my $records = [];

  my $sql = qq(
    SELECT
      help_record_id, data
    FROM
      help_record
    WHERE
      status = 'live'
      AND type = 'movie'
  );

  my $sth = $self->db->prepare($sql);
  $sth->execute();

  while (my @data = $sth->fetchrow_array()) {
    my $record = {
      'id'    => $data[0],
    };
    if ($data[1]) {
      my $extra = eval($data[1]);
      while (my ($k, $v) = each(%$extra)) {
        $record->{$k} = $v;
      }
    }
    push @$records, $record;
  }
  ## Have to sort post-query, since it's on a 'data' field
  my @sorted = sort {
      $a->{'list_position'} <=> $b->{'list_position'}                
      || $a->{'title'} cmp $b->{'title'}
    } @$records;
  return \@sorted;
}

sub fetch_glossary {
  my $self = shift;
  return unless $self->db;
  my $records = [];

  my $sql = qq(
    SELECT
      help_record_id, data
    FROM
      help_record
    WHERE
      status = 'live'
      AND type = 'glossary'
  );

  my $sth = $self->db->prepare($sql);
  $sth->execute();

  while (my @data = $sth->fetchrow_array()) {
    my $record = {
      'id'    => $data[0],
    };
    if ($data[1]) {
      my $extra = eval($data[1]);
      while (my ($k, $v) = each(%$extra)) {
        $record->{$k} = $v;
      }
    }
    push @$records, $record;
  }
  ## Have to sort post-query, since it's on a 'data' field
  my @sorted = sort {
      lc($a->{'word'}) cmp lc($b->{'word'})
    } @$records;
  return \@sorted;
}

##---------------- NEWS ------------------------

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

sub fetch_news {
### Selects all news items for a given release and returns them as an arrayref of hashes
  my ($self, $criteria) = @_;
  my $news_items = [];
  return [] unless $self->db;

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
