package EnsEMBL::Web::Component::Transcript::TextDAS;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Component::Gene::TextDAS);

sub _das_query_object {
  my $self = shift;
  return $self->object->Obj->translation;
}

1;