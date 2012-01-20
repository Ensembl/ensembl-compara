# $Id$

package EnsEMBL::Web::Component::LRG::LRGSeq;

use strict;

use base qw(EnsEMBL::Web::Component::Gene::GeneSeq);

sub _init {
  my $self = shift;
  my $hub  = $self->hub;
  
  $self->SUPER::_init;
  $self->{'subslice_length'} = $hub->param('force') || 10000 * ($hub->param('display_width') || 60);
}

sub content_rtf {
  my $self = shift;
  my ($sequence, $config) = $self->initialize($self->object->Obj);
  return $self->export_sequence($sequence, $config, "LRG-Sequence-$config->{'species'}-$config->{'gene_name'}");
}

1;
