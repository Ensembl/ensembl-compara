# Proxy object to adapt AssemblyMapper to the core Mapper interface.
# Differences:
#   AssemblyMapper uses a 'map' method, not 'map_coordinates'
#   AssemblyMapper uses objects when identifying from/to, not strings, and also
#     likes to reverse the from/to order
#   AssemblyMapper uses seq_region_id rather than seq_region_name in output
package Bio::EnsEMBL::ExternalData::DAS::GenomicMapper;

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