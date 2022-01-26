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

package EnsEMBL::Web::TextSequence::View;

use strict;
use warnings;

use File::Basename;
use JSON qw(encode_json);
use List::Util qw(max);
use List::MoreUtils qw(any firstidx);

use EnsEMBL::Web::PureHub;
use EnsEMBL::Web::TextSequence::Sequence;
use EnsEMBL::Web::TextSequence::Output::Web;
use EnsEMBL::Web::TextSequence::Legend;

use EnsEMBL::Web::TextSequence::ClassToStyle::CSS;

use EnsEMBL::Web::TextSequence::SequenceSet;

# A view is comprised of one or more interleaved sequences.

sub new {
  my ($proto,$hub) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    hub => $hub,
    output => undef,
    legend => undef,
    phase => 0,
    sequenceset => undef,
  };
  bless $self,$class;
  $self->output(EnsEMBL::Web::TextSequence::Output::Web->new);
  $self->reset;
  return $self;
}

# XXX should probably be in SequenceSet, but for that we need custom
# SequenceSets.
sub make_sequence { # For IoC: override me if you want to
  my ($self,$set) = @_;

  return EnsEMBL::Web::TextSequence::Sequence->new($self,$set);
}


# XXX deprecate
sub reset {
  my ($self) = @_;

  $self->{'sequenceset'} = EnsEMBL::Web::TextSequence::SequenceSet->new($self);
  $self->output->reset;
}

sub phase { $_[0]->{'phase'} = $_[1] if @_>1; return $_[0]->{'phase'}; }
sub interleaved { return 1; }

sub output {
  my ($self,$output) = @_;

  if(@_>1) {
    $self->{'output'} = $output;
    $output->view($self);
  }
  return $self->{'output'};
}

sub make_legend { # For IoC: override me if you want to
  return EnsEMBL::Web::TextSequence::Legend->new(@_);
}

sub legend {
  my ($self) = @_;

  $self->{'legend'} ||= $self->make_legend;
  return $self->{'legend'};
}

# XXX into subclasses
sub set_annotations {
  my ($self,$config) = @_;

  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Sequence->new);
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Alignments->new) if $config->{'align'};
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Variations->new([0,2])) if $config->{'snp_display'} && $config->{'snp_display'} ne 'off';
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Exons->new) if ($config->{'exon_display'}||'off') ne 'off';
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Codons->new) if $config->{'codons_display'};
}

sub set_markup {}

sub new_sequence {
  my ($self,$position) = @_;

  return $self->{'sequenceset'}->new_sequence($position);
}

sub sequences { return $_[0]->{'sequenceset'}->sequences; }
sub root_sequences { return $_[0]->{'sequenceset'}->root_sequences; }

sub slices { my $self = shift; return $self->{'sequenceset'}->slices(@_); }

# Only to be called by line
sub _new_line_num { return $_[0]->{'sequenceset'}->_new_line_num; }
sub _hub { return $_[0]->{'hub'}; }

sub width { $_[0]->{'width'} = $_[1] if @_>1; return $_[0]->{'width'}; }

sub add_annotation {
  my $self = shift;

  return $self->{'sequenceset'}->add_annotation(@_);
}

# XXX should all be in annotation: markup is too late
sub add_markup {
  my $self = shift;

  return $self->{'sequenceset'}->add_markup(@_);
}

sub prepare_ropes {
  my $self = shift;

  return $self->{'sequenceset'}->prepare_ropes(@_);
}

sub annotate {
  my $self = shift;

  return $self->{'sequenceset'}->annotate(@_);
}

sub markup {
  my $self = shift;

  return $self->{'sequenceset'}->markup(@_);
}

sub transfer_data {
  my $self = shift;

  return $self->{'sequenceset'}->transfer_data(@_);
}

sub transfer_data_new {
  my $self = shift;

  return $self->{'sequenceset'}->transfer_data_new(@_);
}

sub style_files {
  my ($name,$path) = fileparse(__FILE__);
  $path .= "/seq-styles.yaml";
  return [$path];
}

1;
