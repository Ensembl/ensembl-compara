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

Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor

=head1 DESCRIPTION

Base class for the adaptors that deal with sets of members, like
FamilyAdaptor or HomologyAdaptor

NB: only used to provide fetch_all_by_method_link_type() to those
two adaptors

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;
use DBI qw(:sql_types);

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


=head2 fetch_all_by_method_link_type

  Arg [1]    : string $method_link_type
               the method type used to filter the objects
  Example    : $homologies = $adaptor->fetch_all_by_method_link_type('ENSEMBL_ORTHOLOGUES')
  Description: Returns the list of all the objects whose MethodLinkSpeciesSet
                matches the method with the type $method_link_type
  Returntype : ArrayRef of MemberSet
  Exceptions : thrown if $method_link_type is not defined
  Caller     : general

=cut

sub fetch_all_by_method_link_type {
    my ($self, $method_link_type) = @_;

    $self->throw("method_link_type arg is required\n")
        unless ($method_link_type);

    my @tabs = $self->_tables;
    my ($name, $syn) = @{$tabs[0]};

    my $join = [ [['method_link_species_set', 'mlss'], "mlss.method_link_species_set_id = $syn.method_link_species_set_id"], [['method_link'], 'method_link.method_link_id = mlss.method_link_id'] ];
    my $constraint = 'method_link.type = ?';

    $self->bind_param_generic_fetch($method_link_type, SQL_VARCHAR);

    return $self->generic_fetch($constraint, $join);
}


1;
