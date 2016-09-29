=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

# A view is comprised of one or more interleaved sequences.

sub new {
  my ($proto,$hub) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    hub => $hub,
    output => undef,
    legend => undef,
    phase => 0,
  };
  bless $self,$class;
  $self->output(EnsEMBL::Web::TextSequence::Output::Web->new);
  $self->reset;
  return $self;
}

sub reset {
  my ($self) = @_;

  %$self = (
    %$self,
    all_line => 0,
    annotation => [],
    markup => [],
    slices => [],
    sequences => [],
    rootsequences => [],
    fieldsize => {},
    lines => [],
  );
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
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Variations->new([0,2])) if $config->{'snp_display'} ne 'off';
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Exons->new) if ($config->{'exon_display'}||'off') ne 'off';
  $self->add_annotation(EnsEMBL::Web::TextSequence::Annotation::Codons->new) if $config->{'codons_display'};
}

sub set_markup {}

sub make_sequence { # For IoC: override me if you want to
  my ($self) = @_;

  return EnsEMBL::Web::TextSequence::Sequence->new($self);
}

sub new_sequence {
  my ($self,$position) = @_;

  my $seq = $self->make_sequence();
  if(($position||'') eq 'top') {
    unshift @{$self->{'sequences'}},$seq;
  } else {
    push @{$self->{'sequences'}},$seq;
  }
  return $seq;
}

sub sequences { return $_[0]->{'sequences'}; }
sub root_sequences { return $_[0]->{'root_sequences'}; }

sub add_root { push @{$_[0]->{'root_sequences'}},$_[1]; }

sub slices { $_[0]->{'slices'} = $_[1] if @_>1; return $_[0]->{'slices'}; }

# Only to be called by line
sub _new_line_num { return $_[0]->{'all_line'}++; }
sub _hub { return $_[0]->{'hub'}; }

sub width { $_[0]->{'width'} = $_[1] if @_>1; return $_[0]->{'width'}; }
sub lines { return $_[0]->{'lines'}; }

# Only to be called from sequence
sub _add_line {
  my ($self,$seq,$data) = @_;

  push @{$self->{'lines'}[$seq]},$data;
}

sub field_size {
  my ($self,$key,$value) = @_;

  if(@_>2) {
    $self->{'fieldsize'}{$key} = max($self->{'fieldsize'}{$key}||0,$value);
  }
  return $self->{'fieldsize'}{$key};
}

sub add_annotation {
  my ($self,$annotation) = @_;

  my $replaces = $annotation->replaces;
  if($replaces) {
    my $idx = firstidx { $_->name eq $replaces } @{$self->{'annotation'}};
    return if $idx==-1;
    $self->{'annotation'}[$idx] = $annotation;
  } else {
    push @{$self->{'annotation'}},$annotation;
  }
  $annotation->view($self);
}

# XXX should all be in annotation: markup is too late
sub add_markup {
  my ($self,$markup) = @_;

  my $replaces = $markup->replaces;
  if($replaces) {
    my $idx = firstidx { $_->name eq $replaces } @{$self->{'markup'}};
    return if $idx==-1;
    $self->{'markup'}[$idx] = $markup;
  } else {
    push @{$self->{'markup'}},$markup;
  }
  $markup->view($self);
}

sub prepare_ropes {
  my ($self,$config,$slices) = @_;

  foreach my $a (@{$self->{'annotation'}}) {
    $a->prepare_ropes($config,$slices);
  }
}

sub annotate {
  my ($self,$config,$slice_data,$markup,$seq,$sequence) = @_;

  # XXX should be elsewhere
  $config->{'species'} = $self->_hub->species;
  $config->{'type'} = $self->_hub->get_db;
  #
  my $ph = EnsEMBL::Web::PureHub->new($self->_hub);
  my $cur_phase = $self->phase;
  foreach my $a (@{$self->{'annotation'}}) {
    my $p = $a->phases;
    next if $p and not any { $cur_phase == $_ } @$p;
    $a->annotate($config,$slice_data,$markup,$seq,$ph,$sequence);
  }
}

sub markup {
  my ($self,$sequence,$markup,$config) = @_;

  my $cur_phase = $self->phase;
  my @mods;
  foreach my $a (@{$self->{'markup'}}) {
    my $good = 0;
    my $p = $a->phases;
    $good = 1 unless $p and not any { $cur_phase == $_ } @$p;
    $a->prepare($good);
    next if !$good;
    push @mods,$a;
  }
  $_->pre_markup($sequence,$markup,$config,$self->_hub) for @mods;
  $_->markup($sequence,$markup,$config,$self->_hub) for @mods;
}

sub markup_new {
  my ($self,$sequence,$markup,$config) = @_;

  $self->set_markup($config);
  my $cur_phase = $self->phase;
  my @mods;
  foreach my $a (@{$self->{'markup'}}) {
    my $good = 0;
    my $p = $a->phases;
    $good = 1 unless $p and not any { $cur_phase == $_ } @$p;
    $a->prepare($good);
    next if !$good;
    push @mods,$a;
  }
  $_->pre_markup($sequence,$markup,$config,$self->_hub) for @mods;
  $_->markup($sequence,$markup,$config,$self->_hub) for @mods;
}

sub transfer_data {
  my ($self,$data,$config) = @_;

  my @vseqs = @{$self->sequences};
  my $missing = @$data - @vseqs;
  $self->new_sequence for(1..$missing);
  @vseqs = @{$self->sequences};
  $vseqs[0]->principal(1) if @vseqs and not any { $_->principal } @vseqs;
  foreach my $seq (@$data) {
    my $tseq = shift @vseqs;
    $tseq->add_data($seq,$config);
  }
}

sub transfer_data_new {
  my ($self,$config) = @_;

  my $seqs = $self->sequences;
  $seqs->[0]->principal(1) unless any { $_->principal } @$seqs;
  foreach my $seq (@$seqs) {
    $seq->add_data($seq->legacy,$config);
  } 
}

sub style_files {
  my ($name,$path) = fileparse(__FILE__);
  $path .= "/seq-styles.yaml";
  return [$path];
}

1;
