# $Id 

package EnsEMBL::Web::Component::Export::LRG;

use strict;

use base qw(EnsEMBL::Web::Component::Export);

sub content {
  my $self = shift;
  my $object = $self->object;
  
  return $self->export(undef, $object->get_all_transcripts, $object->stable_id);
}

1;
