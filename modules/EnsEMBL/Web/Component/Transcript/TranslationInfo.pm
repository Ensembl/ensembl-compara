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
  my $table        = $self->new_twocol;
  my $transcript   = $object->Obj;
  my $translation  = $transcript->translation;

  $table->add_row('Ensembl version', $translation->stable_id.'.'.$translation->version);

  return $table->render;
}

1;

