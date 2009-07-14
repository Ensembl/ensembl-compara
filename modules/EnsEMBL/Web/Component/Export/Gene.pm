package EnsEMBL::Web::Component::Export::Gene;

use strict;

use base 'EnsEMBL::Web::Component::Export';

sub content {
  my $self = shift;
  my $object = $self->object;
  
  return $self->export(undef, $object->get_all_transcripts, $object->stable_id);
}

1;
