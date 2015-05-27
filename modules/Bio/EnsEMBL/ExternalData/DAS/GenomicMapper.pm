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

# Proxy object to adapt AssemblyMapper to the core Mapper interface.
# Differences:
#   AssemblyMapper uses a 'map' method, not 'map_coordinates'
#   AssemblyMapper uses objects when identifying from/to, not strings, and also
#     likes to reverse the from/to order
#   AssemblyMapper uses seq_region_id rather than seq_region_name in output
package Bio::EnsEMBL::ExternalData::DAS::GenomicMapper;

############################################################################
#
# DEPRECATED MODULE - DAS SUPPORT WILL BE REMOVED FROM ENSEMBL IN RELEASE 83
#
#############################################################################


use strict;
use warnings;

sub new {
  my ( $proto, $from, $to, $from_cs, $to_cs, $assembly_mapper ) = @_;
  my $class = ref $proto || $proto;
  
  my $self = {
    '_mapper' => $assembly_mapper,
    'from'    => $from,
    'to'      => $to,
    'from_cs' => $from_cs,
    'to_cs'   => $to_cs,
  };
  bless $self, $class;
  
  return $self;
}

sub map_coordinates {
  my $self = shift;
  
  my @coords;
  my $sla = $self->{'_mapper'}->adaptor->db->get_SliceAdaptor;
  if ($_[4] eq $self->{'from'}) {
    @coords = $self->{'_mapper'}->map(@_[0..3], $self->{'from_cs'});
  } elsif ($_[4] eq $self->{'to'}) {
    @coords = $self->{'_mapper'}->map(@_[0..3], $self->{'to_cs'});
  } else {
    throw($_[4].' is neither from/to coordinate system');
  }
  
  for my $c ( @coords ) {
    $c->id( $sla->fetch_by_seq_region_id($c->id)->seq_region_name ) if ($c->isa('Bio::EnsEMBL::Mapper::Coordinate'));
  }
  
  return @coords;
}

1;
