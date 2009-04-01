package EnsEMBL::Web::Data::NewsItem;

use strict;
use warnings;
use Data::Dumper;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('news_item');
__PACKAGE__->set_primary_key('news_item_id');

__PACKAGE__->add_queriable_fields(
  title       => 'tinytext',
  content     => 'text',
  declaration => 'text',
  notes       => 'text',
  priority    => 'int',
  status      => "enum('declared','handed_over','postponed','cancelled')",
  news_done   => "enum('N','Y')",
);

__PACKAGE__->add_fields(
  team              => "enum('Compara','Core','Funcgen','Genebuild','Mart','Outreach','Variation','Web')",
  assembly          => "enum('N','Y')",
  gene_set          => "enum('N','Y')",
  repeat_masking    => "enum('N','Y')",
  stable_id_mapping => "enum('N','Y')",
  affy_mapping      => "enum('N','Y')",
  database          => "enum('new','patched')",
);


__PACKAGE__->columns(TEMP => 'category_name');

__PACKAGE__->has_a(release       => 'EnsEMBL::Web::Data::Release');
__PACKAGE__->has_a(news_category => 'EnsEMBL::Web::Data::NewsCategory');
__PACKAGE__->has_many(species    => 'EnsEMBL::Web::Data::ItemSpecies');


__PACKAGE__->set_sql(news_items => qq{
  SELECT DISTINCT
      n.*,
      c.name AS category_name
  FROM
      __TABLE(=n)__
      LEFT JOIN
      __TABLE(EnsEMBL::Web::Data::ItemSpecies=i)__ ON n.news_item_id = i.news_item_id,
      __TABLE(EnsEMBL::Web::Data::NewsCategory=c)__
  WHERE
      n.news_category_id = c.news_category_id
      %s                   -- where
      %s %s                -- order and limit
});


sub fetch_news_items {
  my ($class, $criteria, $attr) = @_;

  my $where = '';
  my @args = ();
  
  foreach my $column ($class->columns) {
    next unless defined $criteria->{$column};
    $where .= " AND n.$column = ? ";
    push @args, $criteria->{$column};
  }
  
  if (ref($criteria->{'category'}) eq 'ARRAY') {
      my $string = join(' OR ', map { 'n.news_category_id = ?' } @{ $where->{'category'} });
      $where .= " AND ($string) " if $string;
      push @args, @{ $where->{'category'} };
  }

  if (exists $criteria->{'species'}) {
    my $sp = $criteria->{'species'};
    if (ref($sp) eq 'ARRAY') { 
      if (@$sp) {
        my $string = join(' OR ', map { $_ ? 'i.species_id = ?' : 'i.species_id IS NULL' } @$sp);
        $where .= " AND ($string) ";
        push @args, grep { $_ } @$sp;
      }
    } elsif ($sp) {
      $where .= ' AND i.species_id = ? ';
      push @args, $sp;
    } else {
      $where .= ' AND i.species_id IS NULL ';
    }
  }

  $attr->{order_by} ||= 'n.release_id DESC, c.priority ASC, n.priority DESC ';
  my $order = " ORDER BY $attr->{order_by} ";
  my $limit = $attr->{limit} ? " LIMIT $attr->{limit} " : '';

  my $sth = $class->sql_news_items($where, $order, $limit);
  $sth->execute(@args);
  
  my @results = $class->sth_to_objects($sth);
  return @results;
}



1;
