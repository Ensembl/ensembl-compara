package Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

use strict;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


=head2 fetch_by_stable_id

  Arg [1]    : string $stable_id
               the unique database identifier for the feature to be obtained
  Example    : $feat = $adaptor->fetch_by_dbID(1234);
  Description: Returns the feature created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::SeqFeature
  Exceptions : thrown if $stable_id is not defined
  Caller     : general

=cut

sub fetch_by_stable_id {
  my ($self, $stable_id) = @_;

  unless(defined $stable_id) {
    $self->throw("fetch_by_stable_id must have an stable_id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${syn}.stable_id = '$stable_id'";

  #return first element of generic_fetch list
  my ($obj) = @{$self->generic_fetch($constraint)};
  return $obj;
}


sub fetch_all_by_method_link_type {
  my ($self, $method_link_type) = @_;

  $self->throw("method_link_type arg is required\n")
    unless ($method_link_type);

  my $mlss_arrayref = $self->db->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type($method_link_type);

  unless (scalar @{$mlss_arrayref}) {
    warning("There is no $method_link_type data stored in the database\n");
    return [];
  }
  
  my @tabs = $self->_tables;
  my ($name, $syn) = @{$tabs[0]};

  my $constraint =  " ${syn}.method_link_species_set_id in (". join (",", (map {$_->dbID} @{$mlss_arrayref})) . ")";

  return $self->generic_fetch($constraint);
}


1;
