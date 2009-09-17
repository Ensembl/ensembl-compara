package EnsEMBL::Web::Data::Bug;

use strict;
use warnings;
use Data::Dumper;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('bug');
__PACKAGE__->set_primary_key('bug_id');

__PACKAGE__->add_queriable_fields(
  title       => 'tinytext',
  content     => 'text',
);

__PACKAGE__->has_many(release   => 'EnsEMBL::Web::Data::BugRelease');
__PACKAGE__->has_many(species   => 'EnsEMBL::Web::Data::BugSpecies');


__PACKAGE__->set_sql(bugs => qq{
  SELECT DISTINCT
      n.*,
  FROM
      __TABLE(=n)__
      LEFT JOIN
      __TABLE(EnsEMBL::Web::Data::BugSpecies=s)__ ON n.bug_id = s.bug_id,
      __TABLE(EnsEMBL::Web::Data::BugRelease=r)__ ON n.bug_id = r.bug_id,
  WHERE
      %s                   -- where
      %s %s                -- order and limit
});


sub fetch_bugs {
  my ($class, $criteria, $attr) = @_;

  my $where = '';
  my @args = ();
  
  foreach my $column ($class->columns) {
    next unless defined $criteria->{$column};
    $where .= " AND n.$column = ? ";
    push @args, $criteria->{$column};
  }
  
  if (exists $criteria->{'release'}) {
    my $sp = $criteria->{'release'};
    if (ref($sp) eq 'ARRAY') { 
      if (@$sp) {
        my $string = join(' OR ', map { $_ ? 'r.release_id = ?' : 'r.release_id IS NULL' } @$sp);
        $where .= " AND ($string) ";
        push @args, grep { $_ } @$sp;
      }
    } elsif ($sp) {
      $where .= ' AND r.release_id = ? ';
      push @args, $sp;
    } else {
      $where .= ' AND r.release_id IS NULL ';
    }
  }

  if (exists $criteria->{'species'}) {
    my $sp = $criteria->{'species'};
    if (ref($sp) eq 'ARRAY') { 
      if (@$sp) {
        my $string = join(' OR ', map { $_ ? 's.species_id = ?' : 's.species_id IS NULL' } @$sp);
        $where .= " AND ($string) ";
        push @args, grep { $_ } @$sp;
      }
    } elsif ($sp) {
      $where .= ' AND s.species_id = ? ';
      push @args, $sp;
    } else {
      $where .= ' AND s.species_id IS NULL ';
    }
  }

  my $limit = $attr->{limit} ? " LIMIT $attr->{limit} " : '';

  my $sth = $class->sql_news_items($where, '', $limit);
  $sth->execute(@args);
  
  my @results = $class->sth_to_objects($sth);
  return @results;
}



1;
