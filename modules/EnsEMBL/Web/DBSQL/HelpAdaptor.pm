package EnsEMBL::Web::DBSQL::HelpAdaptor;

use DBI;

sub new {
  my( $class, $DB ) = @_;
  my $dbh;
  my $self = $DB;
  bless $self, $class;
  return $self;
}

sub db {
  my $self = shift;
  $self->{'dbh'} ||= DBI->connect(
    "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
    $self->{'USER'}, "$self->{'PASS'}", { RaiseError => 1}
  );
  return $self->{'dbh'};
}

sub fetch_all_by_keyword {
  my( $self, $keyword ) = @_;
  return [] unless $self->db;
  my $T = $self->db->selectrow_arrayref(
    "SELECT title, content FROM article WHERE keyword=?", {}, $keyword
  );
  return [] unless $T;
  return [{
    'title'   => $T->[0],
    'keyword' => $keywords,
    'content' => $T->[1],
    'score'   => 1
  }];
}

sub fetch_all_by_string {
  my( $self, $string ) = @_;
  return [] unless $self->db;
  my $T = $self->db->selectall_arrayref(
    "select title, content, keyword, match (title, content) against (?) as score
       from article
     having score > 0
      order by score desc",
    {}, $string
  );
  return [] unless $T;
  return [ map {{
    'title'   => $_->[0],
    'keyword' => $_->[2],
    'content' => $_->[1],
    'score'   => $_->[3]
  }} @$T ];
}

sub fetch_index_list {
  my( $self ) = @_;
  return [] unless $self->db;
  my $T = $self->db->selectall_arrayref(
    "SELECT a.title, a.keyword, c.name, c.priority
       FROM article a, category c where a.category_id = c.category_id
      ORDER by priority, name, title"
  );
  return [ map {{
    'title'    => $_->[0],
    'keyword'  => $_->[1],
    'category' => $_->[2]
  }} @$T ];
}

1;
