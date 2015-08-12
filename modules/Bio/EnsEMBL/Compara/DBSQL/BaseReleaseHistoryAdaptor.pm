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

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::BaseReleaseHistoryAdaptor

=head1 DESCRIPTION

Base class for the adaptors that have the "first_release" and "last_release" columns.


=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::DBSQL::BaseReleaseHistoryAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion;

use Bio::EnsEMBL::Utils::Exception;
use DBI qw(:sql_types);

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor');



=head2 fetch_all_current

  Example     : $object_name->fetch_all_current();
  Description : 
  Returntype  : 
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_current {
    my $self = shift;
    return $self->fetch_all_by_release(software_version());    
}


=head2 fetch_all_by_release

  Example     : $object_name->fetch_all_by_release();
  Description : 
  Returntype  : 
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_by_release {
    my $self = shift;
    my $release_number = shift || throw("A release number must be given");
    return $self->_id_cache->get_all_by_additional_lookup('in_release_'.$release_number, 1);
}


=head2 update_first_last_release

  Example     : $mlss_adaptor->update_first_last_release($mlss);
  Description : Generic method to update first/last_release in the database
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub update_first_last_release {
    my ($self, $object) = @_;
    my %table = (
        'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet' => ['method_link_species_set', 'method_link_species_set_id'],
        'Bio::EnsEMBL::Compara::GenomeDB' => ['genome_db', 'genome_db_id'],
        'Bio::EnsEMBL::Compara::SpeciesSet' => ['species_set_header', 'species_set_id'],
    );
    my $sql = sprintf('UPDATE %s SET first_release = ?, last_release = ? WHERE %s = ?', @{$table{ref($object)}});
    $self->dbc->do($sql, undef, $object->first_release, $object->last_release, $object->dbID);
    $self->_id_cache->put($object->dbID, $object);
}


=head2 retire_object

  Example     : $genome_db_adaptor->retire_object();
  Description : Mark the object as retired, i.e. with a last_release older than the current version
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub retire_object {
    my ($self, $object) = @_;
    return if not $object->is_current;
    if ($object->first_release >= software_version()) {
        # The object was scheduled for release but is now cancelled
        $self->first_release(undef);
    } else {
        $object->last_release(software_version() - 1);
    }
    return $self->update_first_last_release($object);
}


=head2 make_object_current

  Example     : $genome_db_adaptor->make_object_current();
  Description : Mark the object as current, i.e. with a defined first_release and an undefined last_release
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub make_object_current {
    my ($self, $object) = @_;
    return if $object->is_current;
    $object->first_release(software_version()) unless $object->has_been_released;
    $object->last_release(undef);
    return $self->update_first_last_release($object);
}



package Bio::EnsEMBL::Compara::DBSQL::Cache::WithReleaseHistory;

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion;

use base qw/Bio::EnsEMBL::DBSQL::Support::FullIdCache/;

sub support_additional_lookups {
    return 1;
}

sub compute_keys {
    my ($self, $genome_db) = @_;
    if ($genome_db->has_been_released) {
        my $first_release = $genome_db->first_release;
        my $last_release = $genome_db->last_release || software_version();
        return {map {'in_release_'.$_ => 1} $first_release..$last_release};
    } else {
        return {};
    }
}



1;
