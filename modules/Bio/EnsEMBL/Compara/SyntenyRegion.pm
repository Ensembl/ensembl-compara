#
# Ensembl module for Bio::EnsEMBL::Compara::SyntenyRegion
#
# Cared for by Ewan Birney <ensembl-dev@ebi.ac.uk>
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::SyntenyRegion - Synteny region

=head1 SYNOPSIS

  print $this_synteny_region->dbID;

  print $this_synteny_region->method_link_species_set_id;

  my $these_dnafrag_regions = $this_synteny_region->get_all_DnaFragRegions();
  foreach my $this_dnafrag_region (@$these_dnafrag_regions) {
    print $this_dnafrag_region->genome_db->name, ": ", $this_dnafrag_region->slice->name, "\n";
  }

=head1 DESCRIPTION

A Bio::EnsEMBL::Compara::SyntenyRegion object is a container of Bio::EnsEMBL::Compara::DnaFragRegion
objects. Each Bio::EnsEMBL::Compara::DnaFragRegion represent a genomic region which is in synteny
with the other regions represented in the Bio::EnsEMBL::Compara::SyntenyRegion object.

Also, the Bio::EnsEMBL::Compara::SyntenyRegion object implicitly contains a
Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object which defines the type of synteny.

=head1 OBJECT ATTRIBUTES

=over

=item dbID

corresponds to synteny_region.synteny_region_id

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor object to access DB

=item method_link_species_set_id

corresponds to synteny_region.method_link_species_set_id

=back

=head1 CONTACT

Ensembl - ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::SyntenyRegion;

use strict;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Compara::NestedSet;
our @ISA = qw(Bio::EnsEMBL::Compara::NestedSet);

=head2 new_fast

  Arg [-DBID] : integer $dbID
  Arg [-METHOD_LINK_SPECIES_SET_ID]
              : integer $method_link_species_set_id
  Arg [-ADAPTOR]
              : Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor $adaptor
  Example     : none
  Description : This is the default constructor
  Returntype  : Bio::EnsEMBL::Compara::SyntenyRegion object
  Exceptions  : none
  Caller      :
  Status      : Stable

=cut

sub new {
  my ($class, @args) = @_;

  my $self = $class->SUPER::new(@args);

#  my $self = bless {}, $class;

  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $method_link_species_set_id, $adaptor) =
        rearrange([qw(DBID METHOD_LINK_SPECIES_SET_ID ADAPTOR)], @args);

    $dbid && $self->dbID($dbid);
    $method_link_species_set_id && $self->method_link_species_set_id($method_link_species_set_id);
    $adaptor && $self->adaptor($adaptor);
  }

  return $self;
}


=head2 new_fast

  Arg [1]     : hash reference $hashref
  Example     : none
  Description : This is an ultra fast constructor which requires knowledge of
                the objects internals to be used.
  Returntype  : Bio::EnsEMBL::Compara::SyntenyRegion object
  Exceptions  : none
  Caller      :
  Status      : Stable

=cut

sub new_fast {
  my ($class, $hashref) = @_;

  return bless $hashref, $class;
}


=head2 stable_id

DEPRECATED: SyntenyRegions don't have any stable id.

=cut

sub stable_id {
  my $obj = shift;

  deprecate("SyntenyRegions don't have any stable id.");

  if( @_ ) {
    my $value = shift;
    $obj->{'stable_id'} = $value;
  }

  return $obj->{'stable_id'};
}


=head2 method_link_species_set_id

  Arg [1]     : (optional) integer $method_link_species_set_id
  Example     : none
  Description : Getter/setter for the method_link_species_set_id value.
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub method_link_species_set_id {
  my $obj = shift;
  if( @_ ) {
    my $value = shift;
    $obj->{'method_link_species_set_id'} = $value;
  }
  return $obj->{'method_link_species_set_id'};
}


=head2 dbID

  Arg [1]     : (optional) integer $dbID
  Example     : none
  Description : Getter/setter for the dbID value. This corresponds to
                synteny_region.synteny_region_id
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub dbID {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'dbID'} = $value;
  }

  return $obj->{'dbID'};
}


=head2 adaptor

  Arg [1]     : (optional) Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor $adaptor
  Example     : none
  Description : Getter/setter for the adaptor
  Returntype  : Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor object
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub adaptor {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'adaptor'} = $value;
  }

  return $obj->{'adaptor'};
}


=head2 get_all_DnaFragRegions

 Arg  1     : -none-
 Example    : my $all_dnafrag_regions = $obj->get_all_DnaFragRegions();
 Description: returns all the DnaFragRegion objects for this syntenic
              region. This method is an alias for children(), see
              Bio::EnsEMBL::Compara::NestedSet for more details.
 Returntype : a ref. to an array of Bio::EnsEMBL::Compara::DnaFragRegion
              objects
 Exception  :
 Caller     : general
 Status     : Stable

=cut

sub get_all_DnaFragRegions {
  my $obj = shift;

  return $obj->children();
}

1;
