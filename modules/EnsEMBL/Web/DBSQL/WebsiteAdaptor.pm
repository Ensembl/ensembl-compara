=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

  ## Build the correct number of placeholders for the size of the array.
  my $id_string = join(', ', ('?') x scalar(@$ids));
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
  $sth->execute( @$ids );

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

sub fetch_glossary_lookup {
  my $self = shift;
  my $records = {};

  return { map { $_->{'word'} => $_->{'meaning'} } @{ $self->fetch_glossary || [] } };
}

1;
