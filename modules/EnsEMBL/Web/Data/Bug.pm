package EnsEMBL::Web::Data::Bug;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('bug');
__PACKAGE__->set_primary_key('bug_id');

__PACKAGE__->add_queriable_fields(
  title         => 'tinytext',
  content       => 'text',
  first_release => 'int',
  last_release  => 'int',
);

__PACKAGE__->has_many(species   => 'EnsEMBL::Web::Data::BugSpecies');


__PACKAGE__->set_sql(bugs => qq{
  SELECT DISTINCT
      n.*
  FROM
      __TABLE(=n)__
      LEFT JOIN
      __TABLE(EnsEMBL::Web::Data::BugSpecies=s)__ ON n.bug_id = s.bug_id
  WHERE
      %s   
});


sub fetch_bugs {
  my ($class, $criteria) = @_;

  my $current_release = $ENV{'VERSION'};
  my $cutoff = $current_release - 12;
  my @where_strings = ('last_release > '.$cutoff);
  my @args = ();
  
  foreach my $column ($class->columns) {
    next unless defined $criteria->{$column};
    push @where_strings, " n.$column = ? ";
    push @args, $criteria->{$column};
  }
  
  if (exists $criteria->{'species'}) {
    my $sp = $criteria->{'species'};
    if (ref($sp) eq 'ARRAY') { 
      if (@$sp) {
        push @where_strings, '('.join(' OR ', map { $_ ? 's.species_id = ?' : 's.species_id IS NULL' } @$sp).')';
        push @args, grep { $_ } @$sp;
      }
    } elsif ($sp) {
      push @where_strings, ' s.species_id = ? ';
      push @args, $sp;
    } else {
      push @where_strings, ' s.species_id IS NULL ';
    }
  }
  my $where = join(' AND ', @where_strings);

  my $sth = $class->sql_bugs($where);
  $sth->execute(@args);
  
  my @results = $class->sth_to_objects($sth);
  return @results;
}



1;
