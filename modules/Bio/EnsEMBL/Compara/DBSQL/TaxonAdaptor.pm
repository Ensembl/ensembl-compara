# $Id$
# 
# BioPerl module for Bio::EnsEMBL::ExternalData::Family::DBSQL::TaxonAdaptor
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

package Bio::EnsEMBL::ExternalData::Family::DBSQL::TaxonAdaptor;

use vars qw(@ISA);
use strict;

#use Bio::Species;
use Bio::EnsEMBL::ExternalData::Family::Taxon;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Usage   : $taxonadaptor->fetch_by_dbID($id);
 Function: fetches a taxon given its internal database identifier (taxon_id)
 Example : $taxonadaptor->fetch_by_dbID(1)
 Returns : a Bio::EnsEMBL::ExternalData::Family::Taxon object if found, undef otherwise
 Args    : an integer


=cut

sub fetch_by_dbID {
  my ($self,$taxon_id) = @_;

  $self->throw("Should give a defined taxon_id as argument\n") unless (defined $taxon_id);

  my $q = "SELECT taxon_id,genus,species,sub_species,common_name,classification
           FROM taxon
           WHERE taxon_id= ?";

  $q = $self->prepare($q);
  $q->execute($taxon_id);
  
  if (defined (my $rowhash = $q->fetchrow_hashref)) {
    my $taxon = new Bio::EnsEMBL::ExternalData::Family::Taxon;
    
    $taxon->ncbi_taxid($taxon_id); #for bioperl-1-0-0 on
    $taxon->sub_species($rowhash->{sub_species});
    my @classification = split /\s+/,$rowhash->{classification};
    $taxon->classification(@classification);
    $taxon->common_name($rowhash->{common_name});

    return $taxon;
  }

  return undef;
}

=head2 fetch_by_taxon_id

 Title   : fetch_by_taxon_id
 Usage   : $taxonadaptor->fetch_by_taxon_id($id);
 Function: fetches a taxon given its internal database identifier (taxon_id)
 Example : $taxonadaptor->fetch_by_taxon_id(1)
 Returns : a Bio::EnsEMBL::ExternalData::Family::Taxon object if found, undef otherwise
 Args    : an integer


=cut

sub fetch_by_taxon_id {
  my ($self,$taxon_id) = @_;

  $self->throw("Should give a defined taxon_id as argument\n") unless (defined $taxon_id);

  return $self->fetch_by_dbID($taxon_id);
}

=head2 store

 Title   : store
 Usage   : $memberadaptor->store($member)
 Function: Stores a taxon object into the database
 Example : $memberadaptor->store($member)
 Returns : $member->dbID
 Args    : An Bio::EnsEMBL::ExternalData::Taxon object

=cut

sub store {
  my ($self,$taxon) = @_;

  $taxon->isa('Bio::EnsEMBL::ExternalData::Family::Taxon') ||
    $self->throw("You have to store a Bio::EnsEMBL::ExternalData::Family::Taxon object, not a $taxon");

  my $q = "INSERT INTO taxon (taxon_id,genus,species,sub_species,common_name,classification) 
           VALUES (?,?,?,?,?,?)";
  my $sth = $self->prepare($q);
  $sth->execute($taxon->ncbi_taxid,$taxon->genus,$taxon->species,$taxon->sub_species,$taxon->common_name,join " ",$taxon->classification);
  
  $taxon->adaptor($self);


  return $taxon->dbID;
}

=head2 store_if_needed

 Title   : store_if_needed_if_needed
 Usage   : $memberadaptor->store($taxon)
 Function: Stores a taxon object only if it doesn't exists in the database 
 Example : $memberadaptor->store($member)
 Returns : $member->dbID
 Args    : An Bio::EnsEMBL::ExternalData::Taxon object

=cut

sub store_if_needed {
  my ($self,$taxon) = @_;

  my $q = "select taxon_id from taxon where taxon_id = ?";
  $q = $self->prepare($q);
  $q->execute($taxon->ncbi_taxid);
  my $rowhash = $q->fetchrow_hashref;
  if ($rowhash->{taxon_id}) {
    return $rowhash->{taxon_id};
  } else {
    return $self->store($taxon);
  }
}

1;
