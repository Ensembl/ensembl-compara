package EnsEMBL::Web::Data::Faq;

## Representation of a help record for an Ensembl FAQ entry

use strict;
use warnings;

use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('help_record');
__PACKAGE__->set_primary_key('help_record_id');
__PACKAGE__->set_type('faq');

__PACKAGE__->add_fields(
  question         => 'string',
  answer           => 'text',
);

__PACKAGE__->add_queriable_fields(
  keyword     => 'string',
  status      => "enum('draft','live','dead')",
  helpful     => 'int',
  not_helpful => 'int',
);

__PACKAGE__->set_sql(sorted => qq{
      SELECT 
        n.* 
      FROM
        __TABLE(=n)__
      %s                   -- where
      %s %s                -- order and limit 
});

sub fetch_sorted {
  my ($class, $limit) = @_;

  my $where = ' WHERE type = ? AND status = "live"';
  my $order = ' ORDER BY helpful DESC, not_helpful ASC ';
  $limit = " LIMIT $limit " if $limit;
  my @args = ('faq');

  my $sth = $class->sql_sorted($where, $order, $limit);
  $sth->execute(@args);

  my @results = $class->sth_to_objects($sth);
  return @results;
}


1;
