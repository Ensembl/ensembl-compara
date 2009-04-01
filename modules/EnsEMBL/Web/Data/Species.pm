package EnsEMBL::Web::Data::Species;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data);
use EnsEMBL::Web::Data::Release;
use EnsEMBL::Web::DBSQL::WebDBConnection (__PACKAGE__->species_defs);

__PACKAGE__->table('species');
__PACKAGE__->set_primary_key('species_id');

__PACKAGE__->add_queriable_fields(
  code        => 'char(3)',
  name        => 'varchar(255)',
  common_name => 'varchar(32)',
  vega        => "enum('N','Y')",
  dump_notes  => 'text',
  online      => "enum('N','Y')"
);

__PACKAGE__->has_many(releases   => 'EnsEMBL::Web::Data::ReleaseSpecies');
__PACKAGE__->has_many(news_items => 'EnsEMBL::Web::Data::ItemSpecies');

__PACKAGE__->set_sql(in_release => qq{
  SELECT
      s.species_id
  FROM
      species as s, release_species as rs
  WHERE
      s.species_id = rs.species_id
      %s                   -- where
  LIMIT 1
});


__PACKAGE__->set_sql(add_to_release => qq{
    INSERT INTO release_species VALUES (null, %s, %s, %s, %s, '', '')
});

sub get_lookup_values {
  my ($self, $release_id) = @_;
  $release_id = __PACKAGE__->species_defs->ENSEMBL_VERSION unless $release_id;
  my $values;

  my $release = EnsEMBL::Web::Data::Release->new($release_id);
  my @species = $release->species;

  foreach my $species (sort {$a->name cmp $b->name} @species) {
    push @$values, {'id' => $species->species_id, 
                    'lookups' => {
                        'name'        => $species->name, 
                        'common_name' => $species->common_name,
                    },
                    'order' => [qw(name common_name)]};
  }
  return $values;
}


=pod
sub in_release {
  my ($class, $release, $species) = @_;

  my $where = " AND rs.release_id = $release AND s.name = '$species' "; 
  my $sth = $class->sql_in_release($where);
  $sth->execute(@args);

  my @results = $class->sth_to_objects($sth);
  return @results;
}

sub add_to_release {
  my ($class, $release, $species, $gp, $assembly) = @_;

  
  my $sth = $class->sql_add_to_release($release, $species, $gp, $assembly);
  $sth->execute(@args);

  my @results = $class->sth_to_objects($sth);
  return @results;
}
=cut


1;
