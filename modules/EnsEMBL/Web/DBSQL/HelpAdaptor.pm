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

sub fetch_articles {
  my $self = shift;
  my $params = shift || [];
  my $results = [];
  return $results unless $self->handle;

  my $sql = qq(SELECT a.title, a.keyword, a.content, a.status, c.name 
                FROM article as a, category as c WHERE a.category_id = c.category_id);
  my @vars;
  foreach my $criterion (@$params) {
    my $operator = $criterion->[2] || '=';
    $sql .= ' AND '.$criterion->[0]." $operator ?";
    push @vars, $criterion->[1];
  }
  my $T = $self->handle->selectall_arrayref($sql,{},@vars);
  return [] unless $T;
  for (my $i=0; $i<scalar(@$T);$i++) {
    my @array = @{$T->[$i]};
    next unless $array[0];
    push (@$results,
      {
        'title'     => $array[0],
        'keyword'   => $array[1],
        'content'   => $array[2],
        'status'    => $array[3],
        'category'  => $array[4],
      });
  }
  return $results;
}

sub search_articles {
  my( $self, $string ) = @_;
  return [] unless $self->handle;

  my $results = [];
  my (%matches, $id, $score, $rounded);

  my $T = $self->handle->selectall_arrayref(
    "SELECT article_id, MATCH (title, content) AGAINST (?) AS score
        FROM article
        WHERE status = 'in_use'
        HAVING score > 0
        ORDER BY score DESC",
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
                  created_by, UNIX_TIMESTAMP(created_at), modified_by, UNIX_TIMESTAMP(modified_at) 
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

sub helpful {
  my ($self, %params) = @_;
  my $sql = qq(UPDATE help_record SET );
  if ($params{'helpful'}) {
    $sql .= ' helpful = helpful + 1 ';
  }
  else {
    $sql .= ' not_helpful = not_helpful + 1 ';
  } 
  $sql .= qq(WHERE help_record_id = ?);
  #warn "SQL: " . $sql;
  my $sth = $self->{'_handle'}->prepare($sql);
  my $result = $sth->execute($params{'id'});
  return $result;
}


}

1;
