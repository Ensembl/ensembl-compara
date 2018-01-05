=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor

=head1 DESCRIPTION

This adaptor extends the Compara BaseAdaptor and adds convenient
methods to build a full cache of the data

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


# We want to force the cache
sub ignore_cache_override {
    return 1;
}


=head2 fetch_all

  Description: Returns all the objects from this adaptor
  Returntype : arrayref of objects
  Caller     : general

=cut

sub fetch_all {
    my ($self) = @_;

    return [$self->_id_cache->cached_values()];
}



1;

