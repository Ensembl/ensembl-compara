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

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::SyntenyRegion;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument;

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods


=head2 new

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

  my $self = $class->SUPER::new(@args);       # deal with Storable stuff

  if (scalar @args) {
    #do this explicitly.
    my ($method_link_species_set_id, $regions) =
        rearrange([qw(METHOD_LINK_SPECIES_SET_ID REGIONS)], @args);

    $self->_regions($regions) if $regions;
    $method_link_species_set_id && $self->method_link_species_set_id($method_link_species_set_id);
  }

  return $self;
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


=head2 get_all_DnaFragRegions

 Arg  1     : -none-
 Example    : my $all_dnafrag_regions = $obj->get_all_DnaFragRegions();
 Description: returns all the DnaFragRegion objects for this syntenic
              region. This method is an alias for regions()
 Returntype : a ref. to an array of Bio::EnsEMBL::Compara::DnaFragRegion
              objects
 Exception  :
 Caller     : general
 Status     : Stable

=cut

sub get_all_DnaFragRegions {
  my $obj = shift;

  return $obj->{'regions'};
}


=head2 _regions

  Arg [1]     : (optional) Arrayref of Bio::EnsEMBL::Compara::DnaFragRegion $regions
  Example     : none
  Description : Getter/setter for the regions value.
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::DnaFragRegion
  Exceptions  : none
  Caller      : private

=cut

sub _regions {
  my ($obj, $value) = @_;

  if (defined $value) {
    $obj->{'regions'} = $value;
  }

  return $obj->{'regions'};
}

1;
