package EnsEMBL::Web::Data::Help;

## Generic help record object for use in searching

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('help_record');
__PACKAGE__->set_primary_key('help_record_id');

__PACKAGE__->add_queriable_fields(
  type        => 'string',
  data        => 'text',
  keyword     => 'string',
  status      => "enum('draft','live','dead')",
  helpful     => 'int',
  not_helpful => 'int',
);

__PACKAGE__->set_sql(search => qq{
  SELECT
      n.help_record_id, n.type
  FROM
      __TABLE(=n)__
  WHERE
      %s                   -- where
      %s %s                -- order and limit
});

sub search {
  my ($class, $criteria) = @_;

  my $where = ' status = ? and (keyword like ? or data like ?) ';
  my $like = '%'.$criteria->{'string'}.'%';
  my @args = ( 'live', $like, $like ); ## checking two fields for same string
  if ($criteria->{'type'}) {
    $where .= ' and type = ? ';
    push @args, $criteria->{'type'};
  }
  my $order = ' ORDER BY type, helpful DESC, not_helpful ASC ';

  my $sth = $class->sql_search($where, $order);
  my $results = {};
  $sth->execute(@args);
  while (my @data = $sth->fetchrow_array()) {
    $results->{$data[0]} = $data[1];
  }

  return $results;
}

1;
