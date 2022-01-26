=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::View::VariationComparaAlignments;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::View::ComparaAlignments);

use EnsEMBL::Web::TextSequence::Sequence::Comparison;

use EnsEMBL::Web::TextSequence::Annotation::Sequence;
use EnsEMBL::Web::TextSequence::Annotation::Alignments;
use EnsEMBL::Web::TextSequence::Annotation::Variations;
use EnsEMBL::Web::TextSequence::Annotation::FocusVariant;

use EnsEMBL::Web::TextSequence::Markup::VariationConservation;

sub make_sequence {
  return
    EnsEMBL::Web::TextSequence::Sequence::Comparison->new(@_);
}

sub set_annotations {
  my ($self,$config) = @_;

  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Sequence->new);
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Alignments->new) if $config->{'align'};
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::FocusVariant->new);
#  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Variations->new);
}

sub set_markup {
  my ($self,$config) = @_;

  $self->SUPER::set_markup($config);
  $self->add_markup(EnsEMBL::Web::TextSequence::Markup::VariationConservation->new);
}

1;
