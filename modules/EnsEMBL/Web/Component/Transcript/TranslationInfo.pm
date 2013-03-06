# $Id$

package EnsEMBL::Web::Component::Transcript::TranslationInfo;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self         = shift;
  my $object       = $self->object;
  my $transcript   = $object->Obj;
  my $translation  = $transcript->translation;

  return sprintf('<h3>Protein domains for %s.%s</h3>', $translation->stable_id, $translation->version);
}

1;

