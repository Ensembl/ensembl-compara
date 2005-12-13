# $Id$
#
# Module to handle family members
#
# Cared for by Abel Ureta-Vidal <abel@ebi.ac.uk>
#
# Copyright Abel Ureta-Vidal
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Taxon - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

 Abel Ureta-Vidal <abel@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Taxon;

use strict;
use Bio::Species;

our @ISA = qw(Bio::Species);

# new() is inherited from Bio::Species

=head2 adaptor

 Title   : adaptor
 Usage   :
 Function: give the adaptor if known
 Example :
 Returns :
 Args    :


=cut

sub adaptor {
   my ($self, $value) = @_;

   if (defined $value) {
      $self->{'_adaptor'} = $value;
   }

   return $self->{'_adaptor'};
}

=head2 dbID

 Title   : dbID
 Usage   : 
 Function: get/set the dbID (taxon_id) of the taxon
 Example :
 Returns : 
 Args    : 

=cut

sub dbID {
  my ($self,$value) = @_;

  return $self->ncbi_taxid($value);
}

=head2 taxon_id

 Title   : taxon_id
 Usage   : 
 Function: get/set the taxon_id of the taxon
 Example :
 Returns : An integer 
 Args    : 

=cut

sub taxon_id {
  my ($self,$value) = @_;
  
  $self->warn("Taxon->taxon_id is a deprecated method!
Calling Taxon->ncbi_taxid instead!");

  if (defined $value) {
    return $self->ncbi_taxid($value);
  }

  return $self->ncbi_taxid;
}

=head2 ncbi_taxid

 Title   : ncbi_taxid
 Usage   : 
 Function: get/set the ncbi_taxid of the taxon
 Example :
 Returns : An integer 
 Args    : 

=cut

sub ncbi_taxid {
  my ($self,$value) = @_;
  
  # tricks for bioperl-07/bioperl-1-0-0 compliancy
  
  bless $self, "Bio::Species";
  
  if ($self->can("ncbi_taxid")) { # when using bioperl-1-0-0 and later
    if (defined $value) {
      $self->ncbi_taxid($value);
      $self->{'_ncbi_taxid'} = $self->ncbi_taxid;
    }
  } else {  # when using bioperl-07
    if (defined $value) {
      $self->{'_ncbi_taxid'} = $value;
    }
  }

  bless $self, "Bio::EnsEMBL::Compara::Taxon";
  return $self->{'_ncbi_taxid'};
}



=head2 validate_species_name

 Title   : validate_species_name
 Usage   :
 Function: override the inherited method to disable all
           species name checking since some swissprot species
           are not valid by the Bioperl definition
           e.g. SWISSPROT:APV1_DRONO has species novae-hollandiae
           and the - causes this function to throw an exception
 Example :
 Returns : 1
 Args    :

=cut

sub validate_species_name{
  my( $self, $string ) = @_;
  return 1;
}
1;
