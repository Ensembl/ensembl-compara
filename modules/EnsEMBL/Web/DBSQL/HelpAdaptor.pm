package EnsEMBL::Web::DBSQL::HelpAdaptor;

use Class::Std;
use strict;

{
  my %DBAdaptor_of   :ATTR( :name<db_adaptor>   );
  my %SpeciesDefs_of :ATTR( :name<species_defs> );

sub new {
  my $caller = shift;
  my $r = shift;
  my $handle = shift;
  my $class = ref($caller) || $caller;
  my $self = { '_request' => $r };
  if ($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY) {
    eval {
      ## Get the WebsiteDBAdaptor from the registry
      $self->{'_handle'} =  $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->websiteAdaptor();
    };
    unless($self->{'_handle'}) {
       warn( "Unable to connect to authentication database: $DBI::errstr" );
       $self->{'_handle'} = undef;
    }
    my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user();
    $self->{'_user'} = $user->id;
  } else {
    if ($handle) {
      $self->{'_handle'} = $handle;
    } else {
      warn( "NO DB USER DATABASE DEFINED" );
      $self->{'_handle'} = undef;
    }
  }
  bless $self, $class;
  return $self;
}

sub handle {
  my $self = shift;
  return $self->{'_handle'};
}

sub editor {
  my $self = shift;
  return $self->{'_user'};
}


############ HELPVIEW QUERIES ###############

## Two sets of accessor methods are provided, one for the old schema and one for the new

## OLD (non-modular) HELPVIEW

sub fetch_all_by_keyword {
  my( $self, $keyword ) = @_;
  return [] unless $self->handle;

  my $T = $self->handle->selectrow_arrayref(
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
  return [] unless $self->handle;

  my $results = [];
  my (%matches, $id, $score, $rounded);

  my $T = $self->handle->selectall_arrayref(
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
  return [] unless $self->handle;

  my $results = [];

  ## get the article info
  foreach my $article (@{$scores}) {
    my $id = $$article{'id'};
    my $T = $self->handle->selectrow_arrayref(
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
  return [] unless $self->handle;
  my $T = $self->handle->selectall_arrayref(
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

  return [] unless $self->handle;

  my $T = $self->handle->selectrow_arrayref(
    "SELECT help_article_id, title, intro FROM help_article WHERE keyword=?", {}, $keyword
  );
  return [] unless $T;

  my $id      = $T->[0];
  my $title   = $T->[1];
  my $intro   = $T->[2];

  ## get additional modular content
  my $items = [];
  my $A = $self->handle->selectall_arrayref(
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
  return [] unless $self->handle;

  my $results = [];
  my (%matches, $id, $score, $rounded);

  ## search the individual items for the search term
  my $I = $self->handle->selectall_arrayref(
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
  my $A = $self->handle->selectall_arrayref(
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
  return [] unless $self->handle;

  my $results = [];

  ## get the article info
  foreach my $article (@{$scores}) {
    my $id = $$article{'id'};
    my $T = $self->handle->selectrow_arrayref(
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
  return [] unless $self->handle;

  my $sql = qq(
      SELECT a.title, a.keyword, c.name
       FROM help_article a, help_category c 
       WHERE a.help_category_id = c.help_category_id
  );
  if ($status) {
    $sql .= qq( AND status = "$status" );
  }
  $sql .= qq( ORDER BY order_by, name, title);

  my $T = $self->handle->selectall_arrayref($sql);
  return [ map {{
    'title'    => $_->[0],
    'keyword'  => $_->[1],
    'category' => $_->[2]
  }} @$T ];
}

sub fetch_glossary {
  my ($self, $status) = @_;
  return [] unless $self->handle;
  my $results = [];

  my $sql = 'SELECT word_id, word, acronym, meaning FROM glossary ';
  $sql .= qq( WHERE status = "$status" ) if $status;
  $sql .= 'ORDER BY word ASC';
  my $T = $self->handle->selectall_arrayref($sql);
  return [ map {{
    'id'       => $_->[0],
    'word'     => $_->[1],
    'acronym'  => $_->[2],
    'meaning'  => $_->[3],
  }} @$T ];
}

sub fetch_records {
  my ($self, $criteria) = @_;
  return [] unless $self->handle;

  my $sql = qq(SELECT 
                  help_record_id, type, keyword, data, status, helpful, not_helpful, 
                  created_by, created_at, modified_by, modified_at 
                  FROM help_record 
                  );
  if ($criteria && ref($criteria) eq 'ARRAY') {
    $sql .= ' WHERE ';
    foreach my $criterion (@$criteria) {
      my $operator = $criterion->[2] || '=';
      $sql .= $criterion->[0].' '.$operator.' "'.$criterion->[1].'" AND ';
    }
    $sql =~ s/AND\s$//;
  }
  my $T = $self->handle->selectall_arrayref($sql);
  return [ map {{
    'help_record_id'  => $_->[0],
    'type'            => $_->[1],
    'keyword'         => $_->[2],
    'data'            => $_->[3],
    'status'          => $_->[4],
    'helpful'         => $_->[5],
    'not_helpful'     => $_->[6],
    'created_by'      => $_->[7],
    'created_at'      => $_->[8],
    'modified_by'     => $_->[9],
    'modified_at'     => $_->[10],
  }} @$T ];
}


}

1;
