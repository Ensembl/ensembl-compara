=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::View::Transcript;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::View);

use EnsEMBL::Web::TextSequence::Sequence::Transcript;

use EnsEMBL::Web::TextSequence::Markup::Exons;
use EnsEMBL::Web::TextSequence::Markup::Codons;
use EnsEMBL::Web::TextSequence::Markup::Variations;
use EnsEMBL::Web::TextSequence::Markup::TranscriptLineNumbers;

sub make_sequence {
  return
    EnsEMBL::Web::TextSequence::Sequence::Transcript->new(@_);
}

sub set_annotations {
  my ($self,$config) = @_;

  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Sequence->new);
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::TranscriptVariations->new([0,2])) if $config->{'snp_display'} ne 'off';
}

sub set_markup {
  my ($self,$config) = @_;

  $self->add_markup(EnsEMBL::Web::TextSequence::Markup::Exons->new) if $config->{'exons'};
  $self->add_markup(EnsEMBL::Web::TextSequence::Markup::Codons->new) if $config->{'codons'};
  $self->add_markup(EnsEMBL::Web::TextSequence::Markup::Variations->new([0,2])) if $config->{'snp_display'};
  $self->add_markup(EnsEMBL::Web::TextSequence::Markup::TranscriptLineNumbers->new) if $config->{'line_numbering'} ne 'off';
}


1;
