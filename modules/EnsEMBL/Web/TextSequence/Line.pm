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

package EnsEMBL::Web::TextSequence::Line;

use strict;
use warnings;

# Represents a single line of text sequence

sub new {
  my ($proto,$seq) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    pre => "",
    post => "",
    count => 0,
    line_num => $seq->view->_new_line_num,
    hub => $seq->view->_hub,
    seq => $seq,
    markup => [{}],
  };
  bless $self,$class;
  return $self;
}

sub principal { return $_[0]->seq->principal; }
sub seq { return $_[0]->{'seq'}; }
sub line_num { return $_[0]->{'line_num'}; }
sub pre { return $_[0]->seq->{'pre'}.$_[0]->{'pre'}; }
sub post { return $_[0]->{'post'}; }
sub add_pre { $_[0]->{'pre'} .= ($_[1]||''); }
sub add_post { $_[0]->{'post'} .= ($_[1]||''); }

sub post { return $_[0]->{'post'}; }
sub count { return $_[0]->{'count'}; }

sub full { $_[0]->{'count'} >= $_[0]->{'seq'}->view->width }

sub markup {
  my ($self,$k,$v) = @_;

  $self->{'markup'}->[-1]{$k} = $v;
}

sub advance {
  my ($self) = @_;

  push @{$self->{'markup'}},{};
  $self->{'count'}++;
}

sub add {
  my ($self,$config) = @_;

  pop @{$self->{'markup'}};
  foreach my $m (@{$self->{'markup'}}) {
    $self->{'seq'}->fixup_markup($m,$config);
  }
  $self->{'seq'}->view->output->add_line($self,$self->{'markup'},$config);
}

1;
