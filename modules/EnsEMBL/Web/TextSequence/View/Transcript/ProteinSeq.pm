package EnsEMBL::Web::TextSequence::View::Transcript::ProteinSeq;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::View::Transcript);

use EnsEMBL::Web::TextSequence::Markup::Exons;
use EnsEMBL::Web::TextSequence::Markup::Variations;
use EnsEMBL::Web::TextSequence::Markup::LineNumbers;

sub set_annotations {
  my ($self,$config) = @_;

  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Protein::Sequence->new);
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Protein::Variations->new([0,2])) if $config->{'snp_display'} ne 'off';
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Protein::Exons->new) if $config->{'exons'} ne 'off';
}

sub set_markup {
  my ($self,$config) = @_;

  $self->add_markup(EnsEMBL::Web::TextSequence::Markup::Exons->new) if $config->{'exons'};
  $self->add_markup(EnsEMBL::Web::TextSequence::Markup::Variations->new([0,2])) if $config->{'snp_display'};
  $self->add_markup(EnsEMBL::Web::TextSequence::Markup::LineNumbers->new) if ($config->{'line_numbering'}||'') ne 'off';
}

1;
