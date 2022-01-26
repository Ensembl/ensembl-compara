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

package EnsEMBL::Web::TextSequence::Output;

use strict;
use warnings;

use EnsEMBL::Web::TextSequence::ClassToStyle::CSS;
use EnsEMBL::Web::TextSequence::Output::Web::Adorn;
use HTML::Entities qw(encode_entities);
use JSON qw(to_json);
use EnsEMBL::Web::TextSequence::Layout::String;

use List::Util qw(max);
 
sub new {
  my ($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    template =>
      qq(<pre class="text_sequence">%s</pre><p class="invisible">.</p>),
    c2s => undef,
    view => undef,
  };
  bless $self,$class;
  $self->reset;
  return $self;
}

sub reset {
  my ($self) = @_;

  %$self = (
    %$self,
    data => [],
    legend => {},
    more => undef,
  );
}

sub subslicer { return $_[0]; }

sub make_c2s {
  return EnsEMBL::Web::TextSequence::ClassToStyle::CSS->new($_[0]->view);
}

sub c2s { return ($_[0]->{'c2s'} ||= $_[0]->make_c2s); }

sub template { $_[0]->{'template'} = $_[1] if @_>1; return $_[0]->{'template'}; }
sub view { $_[0]->{'view'} = $_[1] if @_>1; return $_[0]->{'view'}; }
sub legend { $_[0]->{'legend'} = $_[1] if @_>1; return $_[0]->{'legend'}; }
sub more { $_[0]->{'more'} = $_[1] if @_>1; return $_[0]->{'more'}; }
sub final_wrapper { return $_[1]; }
sub format_letters { return $_[1]; }

sub prepare_line {
  my ($self,$data,$num,$config,$vskip) = @_;

  return {
    # values
    pre => $data->{'pre'},
    label => $num->{'label'},
    start => $num->{'start'},
    end => $num->{'end'},
    post_label => $num->{'post_label'},
    h_space => $config->{'h_space'},
    letters => $self->format_letters($data->{'line'},$config),
    adid => $data->{'adid'},
    post => $data->{'post'},
    # flags
    number => ($config->{'number'}||'off') ne 'off',
    vskip => $vskip,
    principal => $data->{'principal'},
  };
}

sub goahead_line { return 1; }

sub format_lines {
  my ($self,$layout,$config,$line_numbers,$multi) = @_;

  my $view = $self->view;
  my $ropes = [grep { !$_->hidden } @{$view->sequences}];

  my @lines;
  my $html = "";
  if($view->interleaved) {
    # Interleaved sequences
    # We truncate to the length of the first sequence. This is a bug,
    # but it's one relied on for TranscriptComparison to work.
    my $num_lines = 0;
    $num_lines = @{$ropes->[0]->output->lines}-1 if $ropes and @$ropes and $ropes->[0];
    #
    for my $x (0..$num_lines) {
      my $y = 0;

      foreach my $rope (@$ropes) {
        my $ro = $rope->output->lines;
        my $num = shift @{$line_numbers->{$y}};
        next unless $self->goahead_line($ro->[$x]);
        push @lines,$self->prepare_line($ro->[$x],$num,$config,$multi && $y == $#$ropes);
        $y++;
      }
    }
  } else {
    # Non-interleaved sequences (eg Exon view)
    my $y = 0;
    foreach my $rope (@$ropes) {
      my $ro = $rope->output;
      my $i = 0;
      my $lines = $ro->lines;
      foreach my $x (@$lines) {
        my $num = shift @{$line_numbers->{$y}};
        push @lines,$self->prepare_line($x,$num,$config,$multi && $i == $#$lines);
        $i++;
      }
      $y++;
    }
  }
  $layout->prepare($_) for(@lines);
  $layout->render($_) for(@lines);

  return $layout;
}

1;
