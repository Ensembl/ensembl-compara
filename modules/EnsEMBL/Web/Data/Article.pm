package EnsEMBL::Web::Data::Article;

## Old-style help article

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;
use EnsEMBL::Web::Data;

our @ISA = qw(EnsEMBL::Web::Data);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key('article_id');
  $self->set_adaptor(
    EnsEMBL::Web::DBSQL::MySQLAdaptor->new({
      table   => 'article',
      adaptor => 'websiteAdaptor',
    })
  );

  $self->add_queriable_field({ name => 'keyword', type => 'string' });
  $self->add_queriable_field({ name => 'title'  , type => 'string' });
  $self->add_queriable_field({ name => 'content', type => 'text' });
  $self->add_queriable_field({ name => 'status' , type => "enum('in_use','obsolete','transferred')" });

  $self->add_belongs_to('EnsEMBL::Web::Data::Category');
  $self->populate_with_arguments($args);
}

sub fetch_index_list {
  my( $class ) = @_;

  my $object = $class->new;

  my $T = $object->get_adaptor->get_handle->selectall_arrayref(
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

sub search_articles {
  my( $class, $string ) = @_;

  my $object = $class->new;
  
  my $results = [];
  my (%matches, $id, $score, $rounded);

  my $T = $object->get_adaptor->get_handle->selectall_arrayref(
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
    foreach my $id (@{$hoa{$score}}) {
      push(@results, {'id'=>$id, 'score'=>$score});
    }
  }

  return \@results;
}

}

1;
