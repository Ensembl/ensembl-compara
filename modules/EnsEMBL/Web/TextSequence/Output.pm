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
    c2s => EnsEMBL::Web::TextSequence::ClassToStyle::CSS->new,
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

sub template { $_[0]->{'template'} = $_[1] if @_>1; return $_[0]->{'template'}; }
sub view { $_[0]->{'view'} = $_[1] if @_>1; return $_[0]->{'view'}; }
sub c2s { $_[0]->{'c2s'} = $_[1] if @_>1; return $_[0]->{'c2s'}; }
sub legend { $_[0]->{'legend'} = $_[1] if @_>1; return $_[0]->{'legend'}; }
sub more { $_[0]->{'more'} = $_[1] if @_>1; return $_[0]->{'more'}; }
sub final_wrapper { return $_[1]; }
sub format_letters { return $_[1]; }

sub format_line {
  my ($self,$layout,$data,$num,$config,$vskip) = @_;

  $layout->render({
    # values
    pre => $data->{'pre'},
    label => $num->{'label'},
    start => $num->{'start'},
    h_space => $config->{'h_space'},
    letters => $self->format_letters($data->{'line'},$config),
    adid => $data->{'adid'},
    post => $data->{'post'},
    # flags
    number => ($config->{'number'}||'off') ne 'off',
    vskip => $vskip
  });
}

sub format_lines {
  my ($self,$layout,$config,$line_numbers,$multi) = @_;

  my $output = $self->{'data'};
  my $html = "";
 
  if($self->view->interleaved) {
    # Interleaved sequences
    # We truncate to the length of the first sequence. This is a bug,
    # but it's one relied on for TranscriptComparison to work.
    my $num_lines = 0;
    $num_lines = @{$output->[0]}-1 if $output and @$output and $output->[0];
    #
    for my $x (0..$num_lines) {
      my $y = 0;

      foreach (@$output) {
        my $num = shift @{$line_numbers->{$y}};
        $self->format_line($layout,$_->[$x],$num,$config,$multi && $y == $#$output);
        $y++;
      }
    }
  } else {
    # Non-interleaved sequences (eg Exon view)
    my $y = 0;
    foreach my $seq (@$output) {
      my $i = 0;
      foreach my $x (@$seq) {
        my $num = shift @{$line_numbers->{$y++}};
        $self->format_line($layout,$x,$num,$config,$multi && $i == $#$seq);
        $i++;
      }
    }
  }

  return $layout;
}

1;
