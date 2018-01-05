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

Bio::EnsEMBL::Compara::DnaFragRegion - dnafrag region on one species

=head1 SYNOPSIS

  my $slice = $dnafrag_region->slice;
  my $dnafrag = $dnafrag_region->dnafrag;
  my $genome_db = $dnafrag_region->genome_db;
  my $dnafrag_start = $dnafrag_region->dnafrag_start;
  my $dnafrag_end = $dnafrag_region->dnafrag_end;
  my $dnafrag_strand = $dnafrag_region->dnafrag_strand;
  my $length = $dnafrag_region->length;

=head1 DESCRIPTION

DnaFragRegion are the objects underlying the SyntenyRegion objects. Each synteny is
represented as a Bio::EnsEMBL::Compara::SyntenyRegion object. Each of these objects
contain one Bio::EnsEMBL::Compara::DnaFragRegion object per region which defines the
synteny. For instance, for a syntenic region between human and mouse, there will be
one DnaFragRegion object for the human region and another one for the mouse one.

=head1 OBJECT ATTRIBUTES

=over

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::DnaFragRegionAdaptor object to access DB

=item synteny_region_id

corresponds to dnafrag.synteny_region_id (external ref.)

=item dnafrag_id

corresponds to dnafrag.dnafrag_id (external ref.)

=item dnafrag

Bio::EnsEMBL::Compara::DnaFrag object corresponding to dnafrag_id

=item dnafrag_start

corresponds to dnafrag_region.dnafrag_start

=item dnafrag_end

corresponds to dnafrag_region.dnafrag_end

=item dnafrag_strand

corresponds to dnafrag_region.dnafrag_strand

=back

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::DnaFragRegion;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use base qw(Bio::EnsEMBL::Compara::Locus Bio::EnsEMBL::Storable);


=head2 new

  Arg         : possible keys: ADAPTOR, SYNTENY_REGION_ID
                See also parent object: Bio::EnsEMBL::Compara::Locus
  Example     : none
  Description : Object constructor.
  Returntype  : Bio::EnsEMBL::Compara::DnaFragRegion object
  Exceptions  : none
  Caller      : general

=cut

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  bless $self, $class;

  if (scalar @args) {
    #do this explicitly.
    my ($adaptor, $synteny_region_id) = rearrange([qw(ADAPTOR SYNTENY_REGION_ID)], @args);

    $adaptor && $self->adaptor($adaptor);
    $synteny_region_id && $self->synteny_region_id($synteny_region_id);
  }

  return $self;
}

sub dbID {
    throw("DnaFragRegion objects do not implement dbID()");
}


=head2 synteny_region_id

  Arg 1       : (optional) integer $synteny_region_id
  Example     : my $synteny_region_id = $dnafrag->synteny_region_id;
  Description : Getter/setter for the synteny_region_id attribute
  Returntype  : integer
  Exceptions  : none
  Caller      : general

=cut

sub synteny_region_id {
  my $obj = shift;

  if (@_) {
    my $value = shift;
    $obj->{'synteny_region_id'} = $value;
  }

  return $obj->{'synteny_region_id'};
}


=head2 slice

  Arg 1       : -none-
  Example     : $slice = $dnafragregion->slice;
  Description : Returns the Bio::EnsEMBL::Slice object corresponding to this
                Bio::EnsEMBL::Compara::DnaFrag object.
  Returntype  : Bio::EnsEMBL::Slice object
  Exceptions  : warns when the corresponding Bio::EnsEMBL::Compara::GenomeDB,
                coord_system_name, name or Bio::EnsEMBL::DBSQL::DBAdaptor
                cannot be retrieved and returns undef.
  Caller      : $object->methodname

=cut

sub slice {
    my ($self) = @_;
    return $self->get_Slice();
}


=head2 length

  Arg 1       : -none-
  Example     : $length = $dnafragregion->length;
  Description : Returns the lenght of this DnaFragRegion
  Returntype  : integer
  Exceptions  :
  Caller      : $object->methodname

=cut

sub length {
  my ($self) = @_;

  return $self->dnafrag_end - $self->dnafrag_start + 1;
}

1;
