package EnsEMBL::Web::Data::Article;

use strict;
use warnings;
use base qw(EnsEMBL::Web::CDBI);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('article');
__PACKAGE__->set_primary_key('article_id');

__PACKAGE__->add_queriable_fields(
  keyword => 'string',
  title   => 'string',
  content => 'text',  ## TODO: Remove it from essential fields
  status  => "enum('in_use','obsolete','transferred')",
);

__PACKAGE__->has_a(category => 'EnsEMBL::Web::Data::Category');


## TODO: remove this, and replace with proper object-oriented request
sub fetch_index_list {
  my( $class ) = @_;

  my $T = $class->db_Main->selectall_arrayref(
    "SELECT a.title, a.keyword, c.name, c.priority
       FROM article a, category c where a.category_id = c.category_id
       AND a.status = 'in_use'
      ORDER by priority, name, title"
  );
  return [ map {{
    'title'    => $_->[0],
    'keyword'  => $_->[1],
    'category' => $_->[2]
  }} @$T ];
}

__PACKAGE__->set_sql(full_text => qq{
  SELECT article_id, MATCH (title, content) AGAINST (?) AS score
  FROM article
  WHERE status = 'in_use'
  HAVING score > 0
  ORDER BY score DESC
});



sub search_articles {
  my( $class, $string ) = @_;

  my $results = [];
  my (%matches, $id, $score, $rounded);

  my $T = $class->db_Main->selectall_arrayref(
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
    foreach my $id (@{ $hoa{$score} }) {
      push @results, { id => $id, score => $score };
    }
  }

  return \@results;
}

1;
