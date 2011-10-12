package EnsEMBL::Web::Component::LRG::ProteinSeq;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript::ProteinSeq EnsEMBL::Web::Component::TextSequence);

sub _init {
  my $self = shift;
  $self->object($self->get_transcript); # Become like a transcript
  return $self->SUPER::_init;
}

sub object {
  my $self = shift;
  $self->{'object'} = shift if @_;
  return $self->{'object'};
}

sub get_transcript {
	my $self        = shift;
	my $param       = $self->hub->param('lrgt');
	my $transcripts = $self->builder->object->get_all_transcripts;
  return $param ? grep $_->stable_id eq $param, @$transcripts : $transcripts->[0];
}

sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $translation = $object->translation_object;
  return ($translation ? sprintf '<h2>Protein ID: %s</h2><h3>(Transcript ID: %s)</h3>', $translation->stable_id, $object->stable_id : '') . $self->SUPER::content;
}

1;
