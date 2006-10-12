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

sub disconnect {
  my $self = shift;
  $self->{'dbh'}->disconnect       if $self->{'dbh'};
  $self->{'dbh_write'}->disconnect if $self->{'dbh_write'};
}
sub DESTROY {
  my $self = shift;
  $self->disconnect;
}
sub db_write {
  my $self = shift;
  my $SD = EnsEMBL::Web::SpeciesDefs->new;
  my $user = $SD->ENSEMBL_WRITE_USER;
  my $pass = $SD->ENSEMBL_WRITE_PASS;
  $self->{'dbh_write'} ||= DBI->connect(
    "DBI:mysql:database=$self->{'NAME'};host=$self->{'HOST'};port=$self->{'PORT'}",
    "$user", "$pass", { RaiseError => 1}
  );
  return $self->{'dbh_write'};
}

############ HELPVIEW QUERIES ###############

## Two sets of accessor methods are provided, one for the old schema and one for the new

## OLD (non-modular) HELPVIEW

sub fetch_all_by_keyword {
  my( $self, $keyword ) = @_;
  return [] unless $self->db;

  my $T = $self->db->selectrow_arrayref(
    "SELECT title, content FROM article WHERE keyword=?", {}, $keyword
  );
  return [] unless $T;
  return [{
    'title'   => $T->[0],
    'keyword' => $keyword,
    'content' => $T->[1],
    'score'   => 1
  }];
}

sub fetch_all_by_string {
  my( $self, $string ) = @_;
  return [] unless $self->db;

  my $results = [];
  my (%matches, $id, $score, $rounded);

  my $T = $self->db->selectall_arrayref(
    "select article_id, match (title, content) against (?) as score
       from article
     having score > 0
      order by score desc",
    {}, $string
  );
  return [] unless $T;
  foreach my $article (@$T) {
    $id    = $article->[0];
    $score = $article->[1];
    $rounded = sprintf("%.2f", $score);
    $matches{$id} += $rounded; 
  }
  $results = _sort_scores(\%matches);
  return $results;
}

sub fetch_all_by_scores {
  my( $self, $scores ) = @_;
  return [] unless $self->db;

  my $results = [];

  ## get the article info
  foreach my $article (@{$scores}) {
    my $id = $$article{'id'};
    my $T = $self->db->selectrow_arrayref(
      "SELECT title, keyword FROM article WHERE article_id=?", {}, $id
    );
    push(@$results, {
      'title'   => $T->[0],
      'keyword' => $T->[1],
      'score'   => $$article{'score'},
    });
  }
    
  return $results;
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

## NEW HELPVIEW

sub fetch_article_by_keyword {
  my( $self, $keyword ) = @_;
  my $results = [];

  return [] unless $self->db;

  my $T = $self->db->selectrow_arrayref(
    "SELECT help_article_id, title, intro FROM help_article WHERE keyword=?", {}, $keyword
  );
  return [] unless $T;

  my $id      = $T->[0];
  my $title   = $T->[1];
  my $intro   = $T->[2];

  ## get additional modular content
  my $items = [];
  my $A = $self->db->selectall_arrayref(
       "SELECT header, content 
        FROM help_item as i, article_item as x 
        WHERE i.help_item_id = x.help_item_id
        AND x.help_article_id=?
        ORDER BY order_by", {}, $id 
  );
  foreach my $item (@$A) {
    my $header  = $item->[0];
    my $content = $item->[1];
    push(@$items, {'header'=>$header,'content'=>$content});
  }

  push(@$results, {
      'title'   => $title,
      'intro'   => $intro,
      'items'   => $items,
      'keyword' => $keyword,
      'score'   => 1
  });

  return $results;
}

sub fetch_scores_by_string {
  my( $self, $string ) = @_;
  return [] unless $self->db;

  my $results = [];
  my (%matches, $id, $score, $rounded);

  ## search the individual items for the search term
  my $I = $self->db->selectall_arrayref(
    "SELECT x.help_article_id, match (i.header, i.content) against (?) as score
       FROM help_item i, article_item x
       WHERE i.help_item_id = x.help_item_id
     HAVING score > 0",
    {}, $string
  );
  foreach my $item (@$I) {
    $id    = $item->[0];
    $score = $item->[1];
    $rounded = sprintf("%.2f", $score);
    $matches{$id} += $rounded;
  }

  ## Also search article titles and intros
  my $A = $self->db->selectall_arrayref(
    "SELECT help_article_id, match (title, intro) against (?) as score
       FROM help_article
     HAVING score > 0",
    {}, $string
  );
  foreach my $article (@$A) {
    $id    = $article->[0];
    $score = $article->[1];
    $rounded = sprintf("%.2f", $score);
    $matches{$id} += $rounded; 
  }
  $results = _sort_scores(\%matches);
  return $results;
}

sub _sort_scores {
  my $matches = shift;
  my @results;
  
  ## "reverse" the hash without losing data, i.e. as a hash of arrays
  my %hoa;
  while (my ($id, $score) = each %$matches) {
    push(@{$hoa{$score}}, $id);
  }

  ## turn that into an array of hashes, in descending score order
  foreach my $score (reverse sort keys %hoa) {
    foreach my $id (@{$hoa{$score}}) {
      push(@results, {'id'=>$id, 'score'=>$score});
    }
  }

  return \@results;
}

sub fetch_summaries_by_scores {
  my( $self, $scores ) = @_;
  return [] unless $self->db;

  my $results = [];

  ## get the article info
  foreach my $article (@{$scores}) {
    my $id = $$article{'id'};
    my $T = $self->db->selectrow_arrayref(
      "SELECT title, keyword, summary FROM help_article WHERE help_article_id=?", {}, $id
    );
    push(@$results, {
      'title'   => $T->[0],
      'keyword' => $T->[1],
      'summary' => $T->[2],
      'score'   => $$article{'score'},
    });
  }
    
  return $results;
}

sub fetch_article_index {
  my( $self, $status ) = @_;
  return [] unless $self->db;

  my $sql = qq(
      SELECT a.title, a.keyword, c.name
       FROM help_article a, help_cat c 
       WHERE a.help_cat_id = c.help_cat_id
  );
  if ($status) {
    $sql .= qq( AND status = "$status" );
  }
  $sql .= qq( ORDER BY order_by, name, title);

  my $T = $self->db->selectall_arrayref($sql);
  return [ map {{
    'title'    => $_->[0],
    'keyword'  => $_->[1],
    'category' => $_->[2]
  }} @$T ];
}

sub fetch_glossary {
  my ($self, $status) = @_;
  return [] unless $self->db;
  my $results = [];

  my $sql = 'SELECT word_id, word, acronym, meaning FROM glossary ';
  $sql .= qq( WHERE status = "$status" ) if $status;
  $sql .= 'ORDER BY word ASC';
  my $T = $self->db->selectall_arrayref($sql);
  return [ map {{
    'word_id'  => $_->[0],
    'word'     => $_->[1],
    'acronym'  => $_->[2],
    'meaning'  => $_->[3],
  }} @$T ];
}

sub fetch_movies {
  my ($self, $status) = @_;
  return [] unless $self->db;
  my $results = [];

  my $sql = 'SELECT movie_id, title, filename, filesize, frame_count, frame_rate FROM help_movie ';
  $sql .= qq( WHERE status = "$status" ) if $status;
  $sql .= 'ORDER BY title ASC';
  my $T = $self->db->selectall_arrayref($sql);
  return [ map {{
    'movie_id'    => $_->[0],
    'title'       => $_->[1],
    'filename'    => $_->[2],
    'filesize'    => $_->[3],
    'frame_count' => $_->[4],
    'frame_rate'  => $_->[5],
  }} @$T ];
}

sub fetch_movie_by_id {
  my ($self, $id) = @_;
  return [] unless $self->db;
  my $results = [];

  my $sql = qq(SELECT title, filename, filesize, width, height, frame_count, frame_rate FROM help_movie where movie_id = "$id");
  my $T = $self->db->selectrow_arrayref($sql);
  return {
    'movie_id'    => $id,
    'title'       => $T->[0],
    'filename'    => $T->[1],
    'filesize'    => $T->[2],
    'width'       => $T->[3],
    'height'      => $T->[4],
    'frame_count' => $T->[5],
    'frame_rate'  => $T->[6],
  };
}

############ HELPDB INTERFACE QUERIES ###############

## Web interface methods are provided for the new schema only, since 
## the old schema is no longer used on www.ensembl.org

sub add_help_item {
  my ($self, $item_ref) = @_;
  return [] unless $self->db;

  my %item = %{$item_ref};

  my $header    = $item{'header'};
  my $content   = $item{'content'};
  my $status    = $item{'status'};
  my $user_id   = $item{'user_id'};

  my $sql = qq(INSERT INTO 
                  help_item 
                SET
                  header        = "$header",
                  content       = "$content",
                  status        = "$status",
                  creation_date = NOW(),
                  created_by    = "$user_id"
            );

  my $sth = $self->db_write->prepare($sql);
  my $result = $sth->execute();

  return $result;
}

sub update_help_item {
  my ($self, $item_ref) = @_;
  return [] unless $self->db;

  my %item = %{$item_ref};

  my $item_id   = $item{'help_item_id'};
  my $header    = $item{'header'};
  my $content   = $item{'content'};
  my $status    = $item{'status'};
  my $user_id   = $item{'user_id'};

  my $sql = qq(UPDATE 
                  help_item 
                SET
                  header        = "$header",
                  content       = "$content",
                  status        = "$status",
                  last_updated  = NOW(),
                  updated_by    = "$user_id"
                WHERE
                  help_item_id  = $item_id
            );

  my $sth = $self->db_write->prepare($sql);
  my $result = $sth->execute();

  return $result;
}




1;
