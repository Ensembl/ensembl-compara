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
    seq_num => -1,
    all_line => 0,
    slices => [],
    sequences => [],
    fieldsize => {},
    lines => [],
    phase => 0,
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

sub make_sequence { # For IoC: override me if you want to
  my ($self,$id) = @_;

  return EnsEMBL::Web::TextSequence::Sequence->new($self,$id);
}

sub new_sequence {
  my ($self) = @_;

  $self->{'seq_num'}++;
  my $seq = $self->make_sequence($self->{'seq_num'});
  push @{$self->{'sequences'}},$seq;
  return $seq;
}

sub sequences { return $_[0]->{'sequences'}; }

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

sub transfer_data {
  my ($self,$data,$config) = @_;

  my @vseqs = @{$self->sequences};
  foreach my $seq (@$data) {
    my $tseq;
    if(@vseqs) { $tseq = shift @vseqs; }
    else { $tseq = $self->new_sequence; }
    $tseq->add_data($seq,$config);
  }
}

sub style_files {
  my ($name,$path) = fileparse(__FILE__);
  $path .= "/seq-styles.yaml";
  return [$path];
}

1;
