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
