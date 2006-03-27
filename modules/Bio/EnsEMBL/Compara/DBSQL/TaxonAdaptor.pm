# 
# BioPerl module for Bio::EnsEMBL::Compara::DBSQL::TaxonAdaptor
# 
# Cared by Abel Ureta-Vidal <abel@ebi.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

TaxonAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

=head1 APPENDIX

=cut

package Bio::EnsEMBL::Compara::DBSQL::TaxonAdaptor;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Compara::Taxon;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Exception;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 fetch_by_dbID [deprecated]

 Title   : fetch_by_dbID
 Usage   : $taxonadaptor->fetch_by_dbID($id);
 Function: fetches a taxon given its internal database identifier (taxon_id)
 Example : $taxonadaptor->fetch_by_dbID(1)
 Returns : a Bio::EnsEMBL::Compara::Taxon object if found, undef otherwise
 Args    : an integer


=cut

sub fetch_by_dbID {
  my ($self,$taxon_id) = @_;

  deprecate("calling Bio::EnsEMBL::Compara::NCBITaxonAdaptor::fetch_node_by_taxon_id method instead.");

  my $ncbi_ta = $self->db->get_NCBITaxonAdaptor;
  return $ncbi_ta->fetch_node_by_taxon_id($taxon_id);
}

=head2 fetch_by_taxon_id [deprecated]

 Title   : fetch_by_taxon_id
 Usage   : $taxonadaptor->fetch_by_taxon_id($id);
 Function: fetches a taxon given its internal database identifier (taxon_id)
 Example : $taxonadaptor->fetch_by_taxon_id(1)
 Returns : a Bio::EnsEMBL::Compara::Taxon object if found, undef otherwise
 Args    : an integer


=cut

sub fetch_by_taxon_id {
  my ($self,$taxon_id) = @_;

  deprecate("calling Bio::EnsEMBL::Compara::NCBITaxonAdaptor::fetch_node_by_taxon_id method instead.");

  my $ncbi_ta = $self->db->get_NCBITaxonAdaptor;
  return $ncbi_ta->fetch_node_by_taxon_id($taxon_id);
}

=head2 fetch_by_Family_Member_source [deprecated]

 Title   : fetch_by_Family_Member_source
 Args[0] : Bio::EnsEMBL::Compara::Family object
 Args[1] : string (member\'s source name)
 Usage   : @taxonArray = @$taxonAdaptor->fetch_by_Family_Member_source($family, 'ENSEMBLGENE');
 Function: fetches all the taxon in a family of specified member source
 Returns : reference to array of Bio::EnsEMBL::Compara::Taxon objects

=cut

sub fetch_by_Family_Member_source {
  my ($self, $family, $source_name) = @_;

  deprecate("calling Bio::EnsEMBL::Compara::Family::get_all_taxa_by_member_source_name method instead.");
  return $family->get_all_taxa_by_member_source_name($source_name);
}


=head2 store [deprecated]

 Title   : store
 Usage   : $memberadaptor->store($member)
 Function: Stores a taxon object only if it does not exists in the database
 Example : $memberadaptor->store($member)
 Returns : $member->dbID
 Args    : An Bio::EnsEMBL::Compara::Taxon object

=cut

sub store {
  my ($self,$taxon) = @_;

  deprecate("Bio::EnsEMBL::Compara::NCBITaxonAdaptor is now the new adaptor.
It does not have store method subroutine. The taxonomy data is imported from NCBI Taxonomy database.
Please read ensembl-compara/scripts/taxonomy/README-taxonomy for more information.");
  return undef;
}

=head2 store_if_needed [deprecated]

 Title   : store_if_needed_if_needed
 Usage   : $memberadaptor->store($taxon)
 Function: Stores a taxon object only if it does not exists in the database 
 Example : $memberadaptor->store($member)
 Returns : $member->dbID
 Args    : An Bio::EnsEMBL::Compara::Taxon object

=cut

sub store_if_needed {
  my ($self,$taxon) = @_;

  deprecate("calling store method instead.");
  return $self->store($taxon);
}

1;
