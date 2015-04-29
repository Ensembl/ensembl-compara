=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Data::Species;

use strict;
use warnings;
use base qw(EnsEMBL::Web::CDBI);
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

__PACKAGE__->set_sql(in_release => qq{
  SELECT
      s.species_id
  FROM
      species as s, release_species as rs
  WHERE
      s.species_id = rs.species_id
      %s                   -- where
});


__PACKAGE__->set_sql(add_to_release => qq{
    INSERT INTO release_species VALUES (null, %s, %s, %s, %s, '', '')
});

sub get_lookup_values {
  my ($self, $release_id) = @_;
  $release_id = __PACKAGE__->species_defs->ENSEMBL_VERSION unless $release_id;
  my $values;

  my @species = $self->species($release_id);

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

sub species {
  my ($class, $release, $species) = @_;

  my $where = " AND rs.release_id = ? ";
  my @args = ($release);
 
  if ($species) {
    $where .= " AND s.name = ? ";
    push @args, $species;
  }

  my $sth = $class->sql_in_release($where);
  $sth->execute(@args);

  my @results = $class->sth_to_objects($sth);
  return @results;
}

=pod
sub add_to_release {
  my ($class, $release, $species, $gp, $assembly) = @_;

  
  my $sth = $class->sql_add_to_release($release, $species, $gp, $assembly);
  $sth->execute(@args);

  my @results = $class->sth_to_objects($sth);
  return @results;
}
=cut


1;
