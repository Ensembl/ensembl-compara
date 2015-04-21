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

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This modules contains common methods used when dealing with Core DBAdaptor
objects. Ideally, these methods should be included in the Core API:

- has_karyotype: checks whether there is a non-empty karyotype
- assembly_name: returns the assembly name
- locator: builds a Locator string
- is_high_coverage: checks whether the genome is high coverage

They are all declared under the namespace Bio::EnsEMBL::DBSQL::DBAdaptor
so that they can be called directly on $genome_db->db_adaptor

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

use strict;
use warnings;


# We pretend that all the methods are directly accessible on DBAdaptor
package Bio::EnsEMBL::DBSQL::DBAdaptor;


=head2 assembly_name

  Arg [1]    : Bio::EnsEMBL::DBSQL::DBAdaptor
  Example    : my $assembly_name = $genome_db->db_adaptor->assembly_name;
  Description: Gets the assembly name of this species
  Returntype : string

=cut

sub assembly_name {
    my $core_dba = shift;

    return undef unless $core_dba;
    return undef unless $core_dba->group eq 'core';

    my ($cs) = @{$core_dba->get_CoordSystemAdaptor->fetch_all()};
    my $assembly_name = $cs->version;

    return $assembly_name;
}


=head2 locator

  Arg [1]    : Bio::EnsEMBL::DBSQL::DBAdaptor
  Example    : my $locator = $genome_db->db_adaptor->locator;
  Description: Builds a locator that can be used later with DBLoader
  Returntype : string

=cut

sub locator {
    my $core_dba = shift;
    my $suffix_separator = shift;

    return undef unless $core_dba;
    return undef unless $core_dba->group eq 'core';

    my $species_safe = $core_dba->species();
    if ($suffix_separator) {
        # The suffix was added to attain uniqueness and avoid collision, now we have to chop it off again.
        ($species_safe) = split(/$suffix_separator/, $core_dba->species());
    }

    my $dbc = $core_dba->dbc();

    return sprintf(
          "%s/host=%s;port=%s;user=%s;pass=%s;dbname=%s;species=%s;species_id=%s;disconnect_when_inactive=%d",
          ref($core_dba), $dbc->host(), $dbc->port(), $dbc->username(), $dbc->password(), $dbc->dbname(), $species_safe, $core_dba->species_id, 1,
    );
}


1;
